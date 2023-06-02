// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

//OFT imports
import "tapioca-sdk/dist/contracts/token/oft/v2/OFTV2.sol";
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol";

import "./tOFTCommon.sol";
// import "./tOFTLeverage.sol";
import "./tOFTMarket.sol";
// import "./tOFTStrategy.sol";

import "../TapiocaWrapper.sol";

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

contract TapiocaOFT is tOFTCommon {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    /// @notice The TapiocaWrapper contract, owner of this contract.
    TapiocaWrapper public tapiocaWrapper;

    /// @dev modules are contracts that holds a portion of the market's logic
    enum Module {
        Leverage,
        Market,
        Strategy
    }

    /// @notice returns the leverage module
    // tOFTLeverage public tOFTLeverageModule;
    /// @notice returns the market module
    tOFTMarket public tOFTMarketModule;
    /// @notice returns the strategy module
    // tOFTStrategy public tOFTStrategyModule;

    // ************** //
    // *** EVENTS *** //
    // ************** //
    /// @notice event emitted when a wrap operation is performed
    event Wrap(address indexed _from, address indexed _to, uint256 _amount);
    /// @notice event emitted when an unwrap operation is performed
    event Unwrap(address indexed _from, address indexed _to, uint256 _amount);

    // ******************//
    // *** MODIFIERS *** //
    // ***************** //
    /// @notice Require that the caller is on the host chain of the ERC20.
    modifier onlyHostChain() {
        require(block.chainid == hostChainID, "TOFT: not host chain");
        _;
    }

    /// @notice creates a new TapiocaOFT
    /// @param _lzEndpoint LayerZero endpoint address
    /// @param _isNative true if the underlying ERC20 is actually the chain's native coin
    /// @param _erc20 true the underlying ERC20 address
    /// @param _yieldBox the YieldBox address
    /// @param _name the TOFT name
    /// @param _symbol the TOFT symbol
    /// @param _decimal the TOFT decimal
    /// @param _hostChainID the TOFT host chain LayerZero id
    constructor(
        address _lzEndpoint,
        bool _isNative,
        IERC20 _erc20,
        IYieldBoxBase _yieldBox,
        string memory _name,
        string memory _symbol,
        uint8 _decimal,
        uint256 _hostChainID,
        address payable _tOFTLeverageModule, 
        address payable _tOFTMarketModule, 
        address payable _tOFTStrategyModule
    ) 
        tOFTCommon(_name, _symbol)
        ERC20(
            string(abi.encodePacked("TapiocaOFT-", _name)),
            string(abi.encodePacked("t", _symbol))
        )
    { 
        erc20 = _erc20;
        _decimalCache = _decimal;
        hostChainID = _hostChainID;
        isNative = _isNative;
        yieldBox = _yieldBox;

        tapiocaWrapper = TapiocaWrapper(msg.sender);

        // tOFTLeverageModule = _tOFTLeverageModule;
        tOFTMarketModule = tOFTMarket(_tOFTMarketModule);
        // tOFTStrategyModule = _tOFTStrategyModule;
    }   

    // ************************ //
    // *** PUBLIC FUNCTIONS *** //
    // ************************ //
    /// @notice Wrap an ERC20 with a 1:1 ratio with a fee if existing.
    /// @dev Since it can be executed only on the main chain, if an address exists on the OP chain it will not allowed to wrap.
    /// @param _toAddress The address to wrap the ERC20 to.
    /// @param _amount The amount of ERC20 to wrap.
    function wrap(
        address _fromAddress,
        address _toAddress,
        uint256 _amount
    ) external onlyHostChain {
        _wrap(_fromAddress, _toAddress, _amount);
        emit Wrap(_fromAddress, _toAddress, _amount);
    }

    /// @notice Wrap a native token with a 1:1 ratio with a fee if existing.
    /// @dev Since it can be executed only on the host chain, if an address exists on the linked chain it will not allowed to wrap.
    /// @param _toAddress The address to wrap the tokens to.
    function wrapNative(address _toAddress) external payable onlyHostChain {
        _wrapNative(_toAddress);
        emit Wrap(msg.sender, _toAddress, msg.value);
    }

    /// @notice Unwrap an ERC20/Native with a 1:1 ratio. Called only on host chain.
    /// @param _toAddress The address to unwrap the tokens to.
    /// @param _amount The amount of tokens to unwrap.

    function unwrap(
        address _toAddress,
        uint256 _amount
    ) external onlyHostChain {
        _unwrap(_toAddress, _amount);
        emit Unwrap(msg.sender, _toAddress, _amount);
    }

    /// @notice sends TOFT to a specific chain and performs a borrow operation
    /// @param _from the sender address
    /// @param _to the receiver address
    /// @param lzDstChainId the destination LayerZero id
    /// @param airdropAdapterParams the LayerZero aidrop adapter params
    /// @param borrowParams the borrow operation data
    /// @param withdrawParams the withdraw operation data
    /// @param options the cross chain send operation data
    /// @param approvals the cross chain approval operation data
    function sendToYBAndBorrow(
        address _from,
        address _to,
        uint16 lzDstChainId,
        bytes calldata airdropAdapterParams,
        IBorrowParams calldata borrowParams,
        IWithdrawParams calldata withdrawParams,
        SendOptions calldata options,
        IApproval[] calldata approvals
    ) external payable {
        _executeModule(
            Module.Market, 
            abi.encodeWithSelector(
                tOFTMarket.sendToYBAndBorrow.selector,
                _from,
                _to,
                lzDstChainId,
                airdropAdapterParams,
                borrowParams,
                withdrawParams,
                options,
                approvals
            )
        );
    }

    // ************************* //
    // *** PRIVATE FUNCTIONS *** //
    // ************************* //
    function _extractModule(Module _module) private view returns (address) {
        address module;
        // if (_module == Module.Leverage) {
        //     module = address(tOFTLeverageModule);
        // } else if (_module == Module.Market) {
        //     module = address(tOFTMarketModule);
        // } else if (_module == Module.Strategy) {
        //     module = address(tOFTStrategyModule);
        // }

        // if (module == address(0)) {
        //     revert("TOFT: module not set");
        // }

        return module;
    }

    function _executeModule(
        Module _module,
        bytes memory _data
    ) private returns (bytes memory returnData) {
        bool success = true;
        address module = _extractModule(_module);

        (success, returnData) = module.delegatecall(_data);
        if (!success) {
            revert(_getRevertMsg(returnData));
        }
    }

    function _executeViewModule(
        Module _module,
        bytes memory _data
    ) private view returns (bytes memory returnData) {
        bool success = true;
        address module = _extractModule(_module);

        (success, returnData) = module.staticcall(_data);
        if (!success) {
            revert(_getRevertMsg(returnData));
        }
    }

    function _getRevertMsg(
        bytes memory _returnData
    ) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "tOFT: no return data";
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }

   
}
