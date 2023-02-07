// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './interfaces/ITapiocaOFT.sol';
import './interfaces/IStargateRouter.sol';
import '@rari-capital/solmate/src/auth/Owned.sol';

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
contract Rebalancing is Owned {
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

    IStargateRouter immutable routerETH;
    IStargateRouter immutable router;

    uint256 private constant SLIPPAGE_PRECISION = 1e5;

    // ************************ //
    // *** EVENTS FUNCTIONS *** //
    // ************************ //
    event ConnectedChainUpdated(
        address indexed _srcOft,
        uint16 _dstChainId,
        address indexed _dstOft
    );
    event Rebalanced(
        address indexed _srcOft,
        uint16 _dstChainId,
        uint256 _slippage,
        uint256 _amount,
        bool _isNative
    );
    event RebalanceAmountUpdated(
        address _srcOft,
        uint16 _dstChainId,
        uint256 _amount,
        uint256 _totalAmount
    );

    // ************************ //
    // *** ERRORS FUNCTIONS *** //
    // ************************ //
    error RouterNotValid();
    error ExceedsBalance();
    error DestinationNotValid();
    error SlippageNotValid();
    error FeeAmountNotSet();
    error PoolInfoRequired();
    error RebalanceAmountNotSet();

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

    constructor(address _routerETH, address _router) Owned(msg.sender) {
        if (_router == address(0)) revert RouterNotValid();
        if (_routerETH == address(0)) revert RouterNotValid();
        routerETH = IStargateRouter(_routerETH);
        router = IStargateRouter(_router);
    }

    // ************************ //
    // *** PUBLIC FUNCTIONS *** //
    // ************************ //

    function checker(address payable _srcOft, uint16 _dstChainId)
        external
        view
        returns (bool canExec, bytes memory execPayload)
    {
        bytes memory ercData;
        if (ITapiocaOFT(_srcOft).isNative()) {
            ercData = abi.encode(
                connectedOFTs[_srcOft][_dstChainId].srcPoolId,
                connectedOFTs[_srcOft][_dstChainId].dstPoolId
            );
        }

        canExec = connectedOFTs[_srcOft][_dstChainId].rebalanceable > 0;
        execPayload = abi.encodeCall(
            Rebalancing.rebalance,
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

        //extract
        ITapiocaOFT(_srcOft).extractUnderlying(_amount);

        //send
        bool _isNative = ITapiocaOFT(_srcOft).isNative();
        if (_isNative) {
            if (msg.value <= _amount) revert FeeAmountNotSet();
            _sendNative(_srcOft, _amount, _dstChainId, _slippage);
        } else {
            if (msg.value == 0) revert FeeAmountNotSet();
            _sendToken(_srcOft, _amount, _dstChainId, _slippage, _ercData);
        }

        connectedOFTs[_srcOft][_dstChainId].rebalanceable -= _amount;
        emit Rebalanced(_srcOft, _dstChainId, _slippage, _amount, _isNative);
    }

    function initConnectedOFT(
        address _srcOft,
        uint16 _dstChainId,
        address _dstOft,
        bytes memory _ercData
    ) external onlyOwner {
        bool isNative = ITapiocaOFT(_srcOft).isNative();
        if (!isNative && _ercData.length == 0) revert PoolInfoRequired();

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
    function _sendNative(
        address payable _oft,
        uint256 _amount,
        uint16 _dstChainId,
        uint256 _slippage
    ) private {
        if (address(this).balance < _amount) revert ExceedsBalance();

        routerETH.swapETH(
            _dstChainId,
            _oft, //refund
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
        if (ITapiocaOFT(_oft).erc20().balanceOf(address(this)) < _amount)
            revert ExceedsBalance();

        (uint256 _srcPoolId, uint256 _dstPoolId) = abi.decode(
            _data,
            (uint256, uint256)
        );

        IStargateRouter.lzTxObj memory _lzTxParams = IStargateRouterBase
            .lzTxObj({
                dstGasForCall: 0,
                dstNativeAmount: msg.value,
                dstNativeAddr: abi.encode(
                    connectedOFTs[_oft][_dstChainId].dstOft
                )
            });

        ITapiocaOFT(_oft).erc20().approve(address(router), _amount);
        router.swap(
            _dstChainId,
            _srcPoolId,
            _dstPoolId,
            _oft, //refund,
            _amount,
            _computeMinAmount(_amount, _slippage),
            _lzTxParams,
            _lzTxParams.dstNativeAddr,
            '0x'
        );
    }

    function _computeMinAmount(uint256 _amount, uint256 _slippage)
        private
        pure
        returns (uint256)
    {
        return _amount - ((_amount * _slippage) / SLIPPAGE_PRECISION);
    }

    receive() external payable {}
}
