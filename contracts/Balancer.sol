// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "tapioca-periph/contracts/interfaces/ITapiocaOFT.sol";
import "tapioca-periph/contracts/interfaces/IStargateRouter.sol";
import "tapioca-periph/contracts/interfaces/IStargateEthVault.sol";
import "@rari-capital/solmate/src/auth/Owned.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

//
//                 .(%%%%%%%%%%%%*       *
//             #%%%%%%%%%%%%%%%%%%%%*  ####*
//          #%%%%%%%%%%%%%%%%%%%%%#  /####
//       ,%%%%%%%%%%%%%%%%%%%%%%%   ####.  %
//                                #####
//                              #####
//   #####%#####              *####*  ####%#####*
//  (#########(              #####     ##########.
//  ##########             #####.      .##########
//                       ,####/
//                      #####
//  %%%%%%%%%%        (####.           *%%%%%%%%%#
//  .%%%%%%%%%%     *####(            .%%%%%%%%%%
//   *%%%%%%%%%%   #####             #%%%%%%%%%%
//               (####.
//      ,((((  ,####(          /(((((((((((((
//        *,  #####  ,(((((((((((((((((((((
//          (####   ((((((((((((((((((((/
//         ####*  (((((((((((((((((((
//                     ,**//*,.

/// Transfers tokens to other layers through Stargate
contract Balancer is Owned {
    // ************ //
    // *** VARS *** //
    // ************ //
    /// @notice current OFT => chain => destination OFT
    /// @dev chain ids (https://stargateprotocol.gitbook.io/stargate/developers/chain-ids):
    ///         - Ethereum: 101
    ///         - BNB: 102
    ///         - Avalanche: 106
    ///         - Polygon: 109
    ///         - Arbitrum: 110
    ///         - Optimism: 111
    ///         - Fantom: 112
    ///         - Metis: 151
    ///     pool ids https://stargateprotocol.gitbook.io/stargate/developers/pool-ids
    mapping(address => mapping(uint16 => OFTData)) public connectedOFTs;

    struct OFTData {
        uint256 srcPoolId;
        uint256 dstPoolId;
        address dstOft;
        uint256 rebalanceable;
    }

    /// @notice StargetETH router address
    IStargateRouter public immutable routerETH;
    /// @notice Stargate router address
    IStargateRouter public immutable router;

    uint256 private constant SLIPPAGE_PRECISION = 1e5;

    // ************************ //
    // *** EVENTS FUNCTIONS *** //
    // ************************ //
    /// @notice event emitted when mTapiocaOFT is initialized
    event ConnectedChainUpdated(
        address indexed _srcOft,
        uint16 indexed _dstChainId,
        address indexed _dstOft
    );
    /// @notice event emitted when a rebalance operation is performed
    /// @dev rebalancing means sending an amount of the underlying token to one of the connected chains
    event Rebalanced(
        address indexed _srcOft,
        uint16 indexed _dstChainId,
        uint256 indexed _slippage,
        uint256 _amount,
        bool _isNative
    );
    /// @notice event emitted when max rebalanceable amount is updated
    event RebalanceAmountUpdated(
        address indexed _srcOft,
        uint16 indexed _dstChainId,
        uint256 indexed _amount,
        uint256 _totalAmount
    );

    // ************************ //
    // *** ERRORS FUNCTIONS *** //
    // ************************ //
    /// @notice error thrown when IStargetRouter address is not valid
    error RouterNotValid();
    /// @notice error thrown when value exceeds balance
    error ExceedsBalance();
    /// @notice error thrown when chain destination is not valid
    error DestinationNotValid();
    /// @notice error thrown when dex slippage is not valid
    error SlippageNotValid();
    /// @notice error thrown when fee amount is not set
    error FeeAmountNotSet();
    error PoolInfoRequired();
    error RebalanceAmountNotSet();
    error DestinationOftNotValid();

    // *************************** //
    // *** MODIFIERS FUNCTIONS *** //
    // *************************** //
    modifier onlyValidDestination(address _srcOft, uint16 _dstChainId) {
        if (connectedOFTs[_srcOft][_dstChainId].dstOft == address(0))
            revert DestinationNotValid();
        _;
    }

    modifier onlyValidSlippage(uint256 _slippage) {
        if (_slippage >= 1e5) revert SlippageNotValid();
        _;
    }

    constructor(
        address _routerETH,
        address _router,
        address _owner
    ) Owned(_owner) {
        if (_router == address(0)) revert RouterNotValid();
        if (_routerETH == address(0)) revert RouterNotValid();
        routerETH = IStargateRouter(_routerETH);
        router = IStargateRouter(_router);
    }

    // ************************ //
    // *** PUBLIC FUNCTIONS *** //
    // ************************ //

    function checker(
        address payable _srcOft,
        uint16 _dstChainId
    ) external view returns (bool canExec, bytes memory execPayload) {
        bytes memory ercData;
        if (ITapiocaOFT(_srcOft).erc20() == address(0)) {
            ercData = abi.encode(
                connectedOFTs[_srcOft][_dstChainId].srcPoolId,
                connectedOFTs[_srcOft][_dstChainId].dstPoolId
            );
        }

        canExec = connectedOFTs[_srcOft][_dstChainId].rebalanceable > 0;
        execPayload = abi.encodeCall(
            Balancer.rebalance,
            (
                _srcOft,
                _dstChainId,
                1e3, //1% slippage
                connectedOFTs[_srcOft][_dstChainId].rebalanceable,
                ercData
            )
        );
    }

    // *********************** //
    // *** OWNER FUNCTIONS *** //
    // *********************** //
    function retryRevert(
        uint16 _srcChainId,
        bytes calldata _srcAddress,
        uint256 _nonce
    ) external payable onlyOwner {
        router.retryRevert{value: msg.value}(_srcChainId, _srcAddress, _nonce);
    }

    function instantRedeemLocal(
        uint16 _srcPoolId,
        uint256 _amountLP,
        address _to
    ) external onlyOwner returns (uint256 amountSD) {
        amountSD = router.instantRedeemLocal(_srcPoolId, _amountLP, _to);
    }

    function redeemLocal(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address payable _refundAddress,
        uint256 _amountLP,
        bytes calldata _to,
        IStargateRouter.lzTxObj memory _lzTxParams
    ) external payable onlyOwner {
        router.redeemLocal{value: msg.value}(
            _dstChainId,
            _srcPoolId,
            _dstPoolId,
            _refundAddress,
            _amountLP,
            _to,
            _lzTxParams
        );
    }

    function redeemRemote(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address payable _refundAddress,
        uint256 _amountLP,
        uint256 _minAmountLD,
        bytes calldata _to,
        IStargateRouter.lzTxObj memory _lzTxParams
    ) external payable onlyOwner {
        router.redeemRemote{value: msg.value}(
            _dstChainId,
            _srcPoolId,
            _dstPoolId,
            _refundAddress,
            _amountLP,
            _minAmountLD,
            _to,
            _lzTxParams
        );
    }

    /// @notice performs a rebalance operation
    /// @dev callable only by the owner
    /// @param _srcOft the source TOFT address
    /// @param _dstChainId the destination LayerZero id
    /// @param _slippage the destination LayerZero id
    /// @param _amount the rebalanced amount
    /// @param _ercData custom send data
    function rebalance(
        address payable _srcOft,
        uint16 _dstChainId,
        uint256 _slippage,
        uint256 _amount,
        bytes memory _ercData
    )
        external
        payable
        onlyOwner
        onlyValidDestination(_srcOft, _dstChainId)
        onlyValidSlippage(_slippage)
    {
        if (connectedOFTs[_srcOft][_dstChainId].rebalanceable < _amount)
            revert RebalanceAmountNotSet();

        //check if OFT is still valid
        if (
            !_isValidOft(
                _srcOft,
                connectedOFTs[_srcOft][_dstChainId].dstOft,
                _dstChainId
            )
        ) revert DestinationOftNotValid();

        //extract
        ITapiocaOFT(_srcOft).extractUnderlying(_amount);

        //send
        bool _isNative = ITapiocaOFT(_srcOft).erc20() == address(0);

        if (_isNative) {
            if (msg.value == 0) revert FeeAmountNotSet();
            _sendNative(_srcOft, _amount, _dstChainId, _slippage);
        } else {
            if (msg.value == 0) revert FeeAmountNotSet();
            _sendToken(_srcOft, _amount, _dstChainId, _slippage, _ercData);
        }

        connectedOFTs[_srcOft][_dstChainId].rebalanceable -= _amount;
        emit Rebalanced(_srcOft, _dstChainId, _slippage, _amount, _isNative);
    }

    /// @notice registeres mTapiocaOFT for rebalancing
    /// @param _srcOft the source TOFT address
    /// @param _dstChainId the destination LayerZero id
    /// @param _dstOft the destination TOFT address
    /// @param _ercData custom send data
    function initConnectedOFT(
        address _srcOft,
        uint16 _dstChainId,
        address _dstOft,
        bytes memory _ercData
    ) external onlyOwner {
        bool isNative = ITapiocaOFT(_srcOft).erc20() == address(0);
        if (!isNative && _ercData.length == 0) revert PoolInfoRequired();
        if (!_isValidOft(_srcOft, _dstOft, _dstChainId))
            revert DestinationOftNotValid();

        (uint256 _srcPoolId, uint256 _dstPoolId) = abi.decode(
            _ercData,
            (uint256, uint256)
        );

        OFTData memory oftData = OFTData({
            srcPoolId: _srcPoolId,
            dstPoolId: _dstPoolId,
            dstOft: _dstOft,
            rebalanceable: 0
        });

        connectedOFTs[_srcOft][_dstChainId] = oftData;
        emit ConnectedChainUpdated(_srcOft, _dstChainId, _dstOft);
    }

    /// @notice assings more rebalanceable amount for TOFT
    /// @param _srcOft the source TOFT address
    /// @param _dstChainId the destination LayerZero id
    /// @param _amount the rebalanced amount
    function addRebalanceAmount(
        address _srcOft,
        uint16 _dstChainId,
        uint256 _amount
    ) external onlyValidDestination(_srcOft, _dstChainId) onlyOwner {
        connectedOFTs[_srcOft][_dstChainId].rebalanceable += _amount;
        emit RebalanceAmountUpdated(
            _srcOft,
            _dstChainId,
            _amount,
            connectedOFTs[_srcOft][_dstChainId].rebalanceable
        );
    }

    // ************************* //
    // *** PRIVATE FUNCTIONS *** //
    // ************************* //
    function _isValidOft(
        address _srcOft,
        address _dstOft,
        uint16 _dstChainId
    ) private view returns (bool) {
        bytes memory trustedRemotePath = abi.encodePacked(_dstOft, _srcOft);
        return
            ITapiocaOFT(_srcOft).isTrustedRemote(
                _dstChainId,
                trustedRemotePath
            );
    }

    function _sendNative(
        address payable _oft,
        uint256 _amount,
        uint16 _dstChainId,
        uint256 _slippage
    ) private {
        if (address(this).balance < _amount) revert ExceedsBalance();
        uint256 valueAmount = msg.value + _amount;
        routerETH.swapETH{value: valueAmount}(
            _dstChainId,
            _oft, //refund to the OFT so it can be used for rebalancing purposes in future operations
            abi.encodePacked(connectedOFTs[_oft][_dstChainId].dstOft),
            _amount,
            _computeMinAmount(_amount, _slippage)
        );
    }

    function _sendToken(
        address payable _oft,
        uint256 _amount,
        uint16 _dstChainId,
        uint256 _slippage,
        bytes memory _data
    ) private {
        IERC20Metadata erc20 = IERC20Metadata(ITapiocaOFT(_oft).erc20());
        if (erc20.balanceOf(address(this)) < _amount) revert ExceedsBalance();

        (uint256 _srcPoolId, uint256 _dstPoolId) = abi.decode(
            _data,
            (uint256, uint256)
        );

        IStargateRouter.lzTxObj memory _lzTxParams = IStargateRouterBase
            .lzTxObj({
                dstGasForCall: 0,
                dstNativeAmount: 0,
                dstNativeAddr: "0x0"
            });

        erc20.approve(address(router), 0);
        erc20.approve(address(router), _amount);
        router.swap(
            _dstChainId,
            _srcPoolId,
            _dstPoolId,
            _oft,
            _amount,
            _computeMinAmount(_amount, _slippage),
            _lzTxParams,
            abi.encodePacked(connectedOFTs[_oft][_dstChainId].dstOft),
            "0x"
        );
    }

    function _computeMinAmount(
        uint256 _amount,
        uint256 _slippage
    ) private pure returns (uint256) {
        return _amount - ((_amount * _slippage) / SLIPPAGE_PRECISION);
    }

    receive() external payable {}
}
