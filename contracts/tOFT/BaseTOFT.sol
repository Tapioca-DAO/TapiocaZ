// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "./BaseTOFTStorage.sol";

//TOFT MODULES
import "./modules/BaseTOFTLeverageModule.sol";
import "./modules/BaseTOFTStrategyModule.sol";
import "./modules/BaseTOFTMarketModule.sol";

contract BaseTOFT is BaseTOFTStorage, ERC20Permit {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    // ************ //
    // *** VARS *** //
    // ************ //
    enum Module {
        Leverage,
        Strategy,
        Market
    }
   
    /// @notice returns the leverage module
    BaseTOFTLeverageModule public leverageModule;

    /// @notice returns the Strategy module
    BaseTOFTStrategyModule public strategyModule;

    /// @notice returns the Market module
    BaseTOFTMarketModule public marketModule;

    // ******************//
    // *** MODIFIERS *** //
    // ***************** //
    /// @notice Require that the caller is on the host chain of the ERC20.
    modifier onlyHostChain() {
        require(block.chainid == hostChainID, "TOFT_host");
        _;
    }


    constructor(
        address _lzEndpoint,
        address _erc20,
        IYieldBoxBase _yieldBox,
        string memory _name,
        string memory _symbol,
        uint8 _decimal,
        uint256 _hostChainID,
        address payable _leverageModule,
        address payable _strategyModule,
        address payable _marketModule
    )
        BaseTOFTStorage(
            _lzEndpoint,
            _erc20,
            _yieldBox,
            _name,
            _symbol,
            _decimal,
            _hostChainID
        )
        ERC20Permit(string(abi.encodePacked("TapiocaOFT-", _name)))
    {
        leverageModule = BaseTOFTLeverageModule(_leverageModule);
        strategyModule = BaseTOFTStrategyModule(_strategyModule);
        marketModule = BaseTOFTMarketModule(_marketModule);
    }

    // ********************** //
    // *** VIEW FUNCTIONS *** //
    // ********************** //
    /// @notice decimal number of the ERC20
    function decimals() public view override returns (uint8) {
        if (_decimalCache == 0) return 18; //temporary fix for LZ _sharedDecimals check
        return _decimalCache;
    }

    // ************************ //
    // *** PUBLIC FUNCTIONS *** //
    // ************************ //
    /// @notice sends TOFT to a specific strategy available on another layer
    /// @param from the sender address
    /// @param to the receiver address
    /// @param amount the transferred amount
    /// @param assetId the destination YieldBox asset id
    /// @param lzDstChainId the destination LayerZero id
    /// @param options the operation data
    function sendToStrategy(
        address from,
        address to,
        uint256 amount,
        uint256 share,
        uint256 assetId,
        uint16 lzDstChainId,
        ITapiocaOFT.ISendOptions calldata options
    ) external payable {
        _executeModule(
            Module.Strategy,
            abi.encodeWithSelector(
                BaseTOFTStrategyModule.sendToStrategy.selector,
                from,
                to,
                amount,
                share,
                assetId,
                lzDstChainId,
                options
            )
        );
    }

    /// @notice extracts TOFT from a specific strategy available on another layer
    /// @param from the sender address
    /// @param amount the transferred amount
    /// @param assetId the destination YieldBox asset id
    /// @param lzDstChainId the destination LayerZero id
    /// @param zroPaymentAddress LayerZero ZRO payment address
    /// @param airdropAdapterParam the LayerZero aidrop adapter params
    function retrieveFromStrategy(
        address from,
        uint256 amount,
        uint256 share,
        uint256 assetId,
        uint16 lzDstChainId,
        address zroPaymentAddress,
        bytes memory airdropAdapterParam
    ) external payable {
        _executeModule(
            Module.Strategy,
            abi.encodeWithSelector(
                BaseTOFTStrategyModule.retrieveFromStrategy.selector,
                from,
                amount,
                share,
                assetId,
                lzDstChainId,
                zroPaymentAddress,
                airdropAdapterParam
            )
        );
    }

    /// @notice sends TOFT to a specific chain and performs a borrow operation
    /// @param from the sender address
    /// @param to the receiver address
    /// @param lzDstChainId the destination LayerZero id
    /// @param airdropAdapterParams the LayerZero aidrop adapter params
    /// @param borrowParams the borrow operation data
    /// @param withdrawParams the withdraw operation data
    /// @param options the cross chain send operation data
    /// @param approvals the cross chain approval operation data
    function sendToYBAndBorrow(
        address from,
        address to,
        uint16 lzDstChainId,
        bytes calldata airdropAdapterParams,
        ITapiocaOFT.IBorrowParams calldata borrowParams,
        ITapiocaOFT.IWithdrawParams calldata withdrawParams,
        ITapiocaOFT.ISendOptions calldata options,
        ITapiocaOFT.IApproval[] calldata approvals
    ) external payable {
        _executeModule(
            Module.Market,
            abi.encodeWithSelector(
                BaseTOFTMarketModule.sendToYBAndBorrow.selector,
                from,
                to,
                lzDstChainId,
                airdropAdapterParams,
                borrowParams,
                withdrawParams,
                options,
                approvals
            )
        );
    }

    /// @notice sends TOFT to a specific chain and performs a leverage down operation
    /// @param amount the amount to use
    /// @param leverageFor the receiver address
    /// @param lzData LZ specific data
    /// @param swapData ISwapper specific data
    /// @param externalData external contracts used for the flow
    function sendForLeverage(
        uint256 amount,
        address leverageFor,
        IUSDOBase.ILeverageLZData calldata lzData,
        IUSDOBase.ILeverageSwapData calldata swapData,
        IUSDOBase.ILeverageExternalContractsData calldata externalData
    ) external payable {
        _executeModule(
            Module.Leverage,
            abi.encodeWithSelector(
                BaseTOFTLeverageModule.sendForLeverage.selector,
                amount,
                leverageFor,
                lzData,
                swapData,
                externalData
            )
        );
    }

    // ************************* //
    // *** PRIVATE FUNCTIONS *** //

    //---internal-
    function _wrap(
        address _fromAddress,
        address _toAddress,
        uint256 _amount
    ) internal virtual {
        if (_fromAddress != msg.sender) {
            require(
                allowance(_fromAddress, msg.sender) >= _amount,
                "TOFT_allowed"
            );
        }
        IERC20(erc20).safeTransferFrom(_fromAddress, address(this), _amount);
        _mint(_toAddress, _amount);
    }

    function _wrapNative(address _toAddress) internal virtual {
        require(msg.value > 0, "TOFT_0");
        _mint(_toAddress, msg.value);
    }

    function _unwrap(address _toAddress, uint256 _amount) internal virtual {
        _burn(msg.sender, _amount);

        if (erc20 == address(0)) {
            _safeTransferETH(_toAddress, _amount);
        } else {
            IERC20(erc20).safeTransfer(_toAddress, _amount);
        }
    }

    //---private---
    function _safeTransferETH(address to, uint256 amount) internal {
        (bool sent, ) = to.call{value: amount}("");
        require(sent, "TOFT_failed");
    }

    function _extractModule(Module _module) private view returns (address) {
        address module;
        if (_module == Module.Leverage) {
            module = address(leverageModule);
        } else if (_module == Module.Strategy) {
            module = address(strategyModule);
        } else if (_module == Module.Market) {
            module = address(marketModule);
        }

        if (module == address(0)) {
            revert("TOFT_module");
        }

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

    function _getRevertMsg(
        bytes memory _returnData
    ) internal pure returns (string memory) {
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "TOFT_data";
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }

    //---LZ---
    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) internal virtual override {
        uint256 packetType = _payload.toUint256(0);

        if (packetType == PT_YB_SEND_STRAT) {
            _executeModule(
                Module.Strategy,
                abi.encodeWithSelector(
                    BaseTOFTStrategyModule.strategyDeposit.selector,
                    _srcChainId,
                    _payload,
                    IERC20(address(this))
                )
            );
        } else if (packetType == PT_YB_RETRIEVE_STRAT) {
            _executeModule(
                Module.Strategy,
                abi.encodeWithSelector(
                    BaseTOFTStrategyModule.strategyWithdraw.selector,
                    _srcChainId,
                    _payload
                )
            );
        } else if (packetType == PT_LEVERAGE_MARKET_DOWN) {
            _executeModule(
                Module.Leverage,
                abi.encodeWithSelector(
                    BaseTOFTLeverageModule.leverageDown.selector,
                    _srcChainId,
                    _payload
                )
            );
        } else if (packetType == PT_YB_SEND_SGL_BORROW) {
            _executeModule(
                Module.Market,
                abi.encodeWithSelector(
                    BaseTOFTMarketModule.borrow.selector,
                    _srcChainId,
                    _payload
                )
            );
        } else {
            packetType = _payload.toUint8(0);
            if (packetType == PT_SEND) {
                _sendAck(_srcChainId, _srcAddress, _nonce, _payload);
            } else if (packetType == PT_SEND_AND_CALL) {
                _sendAndCallAck(_srcChainId, _srcAddress, _nonce, _payload);
            } else {
                revert("TOFT_packet");
            }
        }
    }
}
