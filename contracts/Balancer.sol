// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// Tapioca
import {
    IStargateRouter,
    IStargateRouterBase,
    IStargateFactory,
    IStargatePool
} from "tapioca-periph/interfaces/external/stargate/IStargateRouter.sol";
import {IStargateEthVault} from "tapioca-periph/interfaces/external/stargate/IStargateEthVault.sol";
import {ITOFTVault} from "tapioca-periph/interfaces/tapiocaz/ITOFTVault.sol";
import {ITOFT} from "tapioca-periph/interfaces/oft/ITOFT.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

/**
 * @title Balancer
 * @author TapiocaDAO
 * @notice Rebalances mTOFT by transferring underlying tokens to other layers through Stargate
 */
contract Balancer is Ownable {
    using SafeERC20 for IERC20;

    /**
     * @notice current OFT => chain => destination OFT
     * @dev chain ids (https://stargateprotocol.gitbook.io/stargate/developers/chain-ids):
     *         - Ethereum: 101
     *         - BNB: 102
     *         - Avalanche: 106
     *         - Polygon: 109
     *         - Arbitrum: 110
     *         - Optimism: 111
     *         - Fantom: 112
     *         - Metis: 151
     *     pool ids https://stargateprotocol.gitbook.io/stargate/developers/pool-ids
     */
    mapping(address => mapping(uint16 => OFTData)) public connectedOFTs;

    struct OFTData {
        uint256 srcPoolId;
        uint256 dstPoolId;
        address dstOft;
        uint256 rebalanceable;
    }

    IStargateRouter public immutable routerETH;
    IStargateRouter public immutable router;
    IStargateFactory public immutable stargateFactory;

    address public rebalancer;

    // @dev swapEth is not available on some chains
    bool public disableEth;

    mapping(uint16 => uint256) private _sgReceiveGas;

    event ConnectedChainUpdated(address indexed _srcOft, uint16 indexed _dstChainId, address indexed _dstOft);
    event Rebalanced(
        address indexed _srcOft,
        uint16 indexed _dstChainId,
        uint256 indexed _slippage,
        uint256 _amount,
        uint256 _convertedAmount,
        bool _isNative
    );
    event RebalanceAmountUpdated(
        address indexed _srcOft, uint16 indexed _dstChainId, uint256 indexed _amount, uint256 _totalAmount
    );
    event ToggledSwapEth(bool indexed _old, bool indexed _new);
    event EmergencySaved(address indexed _token, uint256 indexed _amount, bool indexed _native);
    event RebalancerUpdated(address indexed prev, address indexed current);

    error NotAuthorized();
    error RouterNotValid();
    error ExceedsBalance();
    error DestinationNotValid();
    error SlippageNotValid();
    error FeeAmountNotSet();
    error PoolInfoRequired();
    error RebalanceAmountNotSet();
    error Failed();
    error SwapNotEnabled();
    error AlreadyInitialized();
    error RebalanceAmountNotValid();
    error GasNotValid();

    modifier onlyValidDestination(address _srcOft, uint16 _dstChainId) {
        if (connectedOFTs[_srcOft][_dstChainId].dstOft == address(0)) {
            revert DestinationNotValid();
        }
        _;
    }

    modifier onlyValidSlippage(uint256 _slippage) {
        // @dev a slippage higher than 20% shouldn't be necessary
        if (_slippage >= 2e4) revert SlippageNotValid();
        _;
    }

    constructor(address _routerETH, address _router, address _factory, address _owner) {
        if (_router == address(0)) revert RouterNotValid();
        if (_routerETH == address(0)) revert RouterNotValid();
        routerETH = IStargateRouter(_routerETH);
        router = IStargateRouter(_router);
        stargateFactory = IStargateFactory(_factory);

        transferOwnership(_owner);
        rebalancer = _owner;
        emit RebalancerUpdated(address(0), _owner);
    }

    receive() external payable {}

    /// =====================
    /// View
    /// =====================
    function checker(address payable _srcOft, uint16 _dstChainId, uint256 _slippage)
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        canExec = connectedOFTs[_srcOft][_dstChainId].rebalanceable > 0;
        execPayload = abi.encodeCall(
            Balancer.rebalance, (_srcOft, _dstChainId, _slippage, connectedOFTs[_srcOft][_dstChainId].rebalanceable)
        );
    }

    /// =====================
    /// Owner
    /// =====================
    /**
     * @notice set lzTxObj `dstGasForCall`
     * @param eid the endpoint address
     * @param gas the gas amount
     */
    function setSgReceiveGas(uint16 eid, uint256 gas) external onlyOwner {
        _sgReceiveGas[eid] = gas;
    }

    /**
     * @notice set rebalancer role
     * @param _addr the new address
     */
    function setRebalancer(address _addr) external onlyOwner {
        rebalancer = _addr;
        emit RebalancerUpdated(rebalancer, _addr);
    }

    /**
     * @notice toggle swap eth
     * @param _val true/false
     */
    function setSwapEth(bool _val) external onlyOwner {
        emit ToggledSwapEth(disableEth, _val);
        disableEth = _val;
    }

    /**
     * @notice performs a rebalance operation
     * @dev callable only by the owner
     * @param _srcOft the source TOFT address
     * @param _dstChainId the destination LayerZero id
     * @param _slippage the destination LayerZero id
     * @param _amount the rebalanced amount
     */
    function rebalance(address payable _srcOft, uint16 _dstChainId, uint256 _slippage, uint256 _amount)
        external
        payable
        onlyValidDestination(_srcOft, _dstChainId)
        onlyValidSlippage(_slippage)
    {
        if (msg.sender != owner() && msg.sender != rebalancer) revert NotAuthorized();

        if (connectedOFTs[_srcOft][_dstChainId].rebalanceable < _amount) {
            revert RebalanceAmountNotSet();
        }

        uint256 convertedAmount = _amount;
        address stargatePool = stargateFactory.getPool(connectedOFTs[_srcOft][_dstChainId].srcPoolId);
        uint256 sharedDecimals = IStargatePool(stargatePool).sharedDecimals();
        uint256 convertRate = IStargatePool(stargatePool).convertRate();
        if (convertRate != 1) {
            // ex: for 10e18 and 6 shared decimals => 10e18 / 1e12 * 1e6, 10e12
            convertedAmount = (_amount / convertRate) * (10 ** sharedDecimals);
        }

        //extract
        ITOFT(_srcOft).extractUnderlying(_amount);

        //send
        {
            bool _isNative = ITOFT(_srcOft).erc20() == address(0);
            if (msg.value == 0) revert FeeAmountNotSet();
            if (_isNative) {
                if (disableEth) revert SwapNotEnabled();
                _sendNative(_srcOft, convertedAmount, _dstChainId, _slippage);
            } else {
                _sendToken(_srcOft, _amount, _dstChainId, _slippage);
            }

            connectedOFTs[_srcOft][_dstChainId].rebalanceable -= _amount;
            emit Rebalanced(_srcOft, _dstChainId, _slippage, _amount, convertedAmount, _isNative);
        }
    }

    /**
     * @notice saves token/native gas from this contract
     * @param _token the token address; `address(0)` should be passed for the Native coin
     * @param _amount the amount to be saved
     */
    function emergencySaveTokens(address _token, uint256 _amount) external onlyOwner {
        if (_token == address(0)) {
            (bool sent,) = msg.sender.call{value: _amount}("");
            if (!sent) revert Failed();
            emit EmergencySaved(_token, _amount, true);
        } else {
            IERC20(_token).safeTransfer(msg.sender, _amount);
            emit EmergencySaved(_token, _amount, false);
        }
    }

    /**
     * @notice registeres mTapiocaOFT for rebalancing
     * @param _srcOft the source TOFT address
     * @param _dstChainId the destination LayerZero id
     * @param _dstOft the destination TOFT address
     * @param _ercData custom send data
     */
    function initConnectedOFT(address _srcOft, uint16 _dstChainId, address _dstOft, bytes memory _ercData)
        external
        onlyOwner
    {
        if (connectedOFTs[_srcOft][_dstChainId].rebalanceable > 0) {
            revert AlreadyInitialized();
        }
        bool isNative = ITOFT(_srcOft).erc20() == address(0);
        if (!isNative && _ercData.length == 0) revert PoolInfoRequired();

        (uint256 _srcPoolId, uint256 _dstPoolId) = abi.decode(_ercData, (uint256, uint256));

        OFTData memory oftData =
            OFTData({srcPoolId: _srcPoolId, dstPoolId: _dstPoolId, dstOft: _dstOft, rebalanceable: 0});

        connectedOFTs[_srcOft][_dstChainId] = oftData;
        emit ConnectedChainUpdated(_srcOft, _dstChainId, _dstOft);
    }

    /**
     * @notice assings more rebalanceable amount for TOFT
     * @param _srcOft the source TOFT address
     * @param _dstChainId the destination LayerZero id
     * @param _amount the rebalanced amount
     */
    function addRebalanceAmount(address _srcOft, uint16 _dstChainId, uint256 _amount)
        external
        onlyValidDestination(_srcOft, _dstChainId)
        onlyOwner
    {
        connectedOFTs[_srcOft][_dstChainId].rebalanceable += _amount;
        uint256 totalToftSupply = ITOFTVault(ITOFT(_srcOft).vault()).viewSupply();
        if (connectedOFTs[_srcOft][_dstChainId].rebalanceable > totalToftSupply) {
            revert RebalanceAmountNotValid();
        }
        emit RebalanceAmountUpdated(_srcOft, _dstChainId, _amount, connectedOFTs[_srcOft][_dstChainId].rebalanceable);
    }

    function retryRevert(uint16 _srcChainId, bytes calldata _srcAddress, uint256 _nonce) external payable onlyOwner {
        router.retryRevert{value: msg.value}(_srcChainId, _srcAddress, _nonce);
    }

    /// =====================
    /// Private
    /// =====================
    function _sendNative(address payable _oft, uint256 _amount, uint16 _dstChainId, uint256 _slippage) private {
        if (address(this).balance < _amount) revert ExceedsBalance();
        uint256 valueAmount = msg.value + _amount;
        uint256 gas = _sgReceiveGas[_dstChainId];
        if (gas == 0) revert GasNotValid();
        IStargateRouterBase.SwapAmount memory swapAmounts =
            IStargateRouterBase.SwapAmount({amountLD: _amount, minAmountLD: _computeMinAmount(_amount, _slippage)});
        IStargateRouterBase.lzTxObj memory lzTxObj =
            IStargateRouterBase.lzTxObj({dstGasForCall: gas, dstNativeAmount: 0, dstNativeAddr: "0x0"});
        routerETH.swapETHAndCall{value: valueAmount}(
            _dstChainId,
            payable(this),
            abi.encodePacked(connectedOFTs[_oft][_dstChainId].dstOft),
            swapAmounts,
            lzTxObj,
            "0x"
        );
    }

    function _sendToken(address payable _oft, uint256 _amount, uint16 _dstChainId, uint256 _slippage) private {
        address erc20 = ITOFT(_oft).erc20();
        if (IERC20Metadata(erc20).balanceOf(address(this)) < _amount) {
            revert ExceedsBalance();
        }
        {
            _routerSwap(__RouterSwapInternal(_dstChainId, _amount, _slippage, _oft, erc20));
        }
    }

    struct __RouterSwapInternal {
        uint16 _dstChainId;
        uint256 _amount;
        uint256 _slippage;
        address payable _oft;
        address _erc20;
    }

    function _routerSwap(__RouterSwapInternal memory swapInternal) private {
        uint256 gas = _sgReceiveGas[swapInternal._dstChainId];
        if (gas == 0) revert GasNotValid();
        IERC20(swapInternal._erc20).safeApprove(address(router), swapInternal._amount);
        router.swap{value: msg.value}(
            swapInternal._dstChainId,
            connectedOFTs[swapInternal._oft][swapInternal._dstChainId].srcPoolId,
            connectedOFTs[swapInternal._oft][swapInternal._dstChainId].dstPoolId,
            payable(this),
            swapInternal._amount,
            _computeMinAmount(swapInternal._amount, swapInternal._slippage),
            IStargateRouterBase.lzTxObj({dstGasForCall: gas, dstNativeAmount: 0, dstNativeAddr: "0x0"}),
            abi.encodePacked(connectedOFTs[swapInternal._oft][swapInternal._dstChainId].dstOft),
            "0x"
        );
        IERC20(swapInternal._erc20).safeApprove(address(router), 0);
    }

    function _computeMinAmount(uint256 _amount, uint256 _slippage) private pure returns (uint256) {
        return _amount - ((_amount * _slippage) / 1e5);
    }
}
