// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "./BaseTOFTStorage.sol";

//TOFT MODULES
import "./modules/BaseTOFTLeverageModule.sol";
import "./modules/BaseTOFTLeverageDestinationModule.sol";
import "./modules/BaseTOFTStrategyModule.sol";
import "./modules/BaseTOFTStrategyDestinationModule.sol";
import "./modules/BaseTOFTMarketModule.sol";
import "./modules/BaseTOFTMarketDestinationModule.sol";
import "./modules/BaseTOFTOptionsModule.sol";
import "./modules/BaseTOFTOptionsDestinationModule.sol";
import "./modules/BaseTOFTGenericModule.sol";
import "./TOFTVault.sol";

import "tapioca-periph/contracts/interfaces/IStargateReceiver.sol";

contract BaseTOFT is BaseTOFTStorage, ERC20Permit, IStargateReceiver {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    // ************ //
    // *** VARS *** //
    // ************ //

    /// @notice returns the leverage module
    BaseTOFTLeverageModule private _leverageModule;
    /// @notice returns the leverage module
    BaseTOFTLeverageDestinationModule private _leverageDestinationModule;

    /// @notice returns the Strategy module
    BaseTOFTStrategyModule private _strategyModule;
    /// @notice returns the Strategy module
    BaseTOFTStrategyDestinationModule private _strategyDestinationModule;

    /// @notice returns the Market module
    BaseTOFTMarketModule private _marketModule;
    /// @notice returns the Market module
    BaseTOFTMarketDestinationModule private _marketDestinationModule;

    /// @notice returns the Options module
    BaseTOFTOptionsModule private _optionsModule;
    /// @notice returns the Options module
    BaseTOFTOptionsDestinationModule private _optionsDestinationModule;

    /// @notice returns the Options module
    BaseTOFTGenericModule private _genericModule;

    /// @notice returns the amount of total wrapped native coins
    uint256 wrappedNativeAmount;

    TOFTVault public vault;

    struct DestinationCall {
        Module module;
        bytes4 functionSelector;
    }
    // Define a mapping from packetType to destination module and function selector.
    mapping(uint256 => DestinationCall) private _destinationMappings;

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
        ICluster _cluster,
        string memory _name,
        string memory _symbol,
        uint8 _decimal,
        uint256 _hostChainID,
        BaseTOFTLeverageModule __leverageModule,
        BaseTOFTLeverageDestinationModule __leverageDestinationModule,
        BaseTOFTStrategyModule __strategyModule,
        BaseTOFTStrategyDestinationModule __strategyDestinationModule,
        BaseTOFTMarketModule __marketModule,
        BaseTOFTMarketDestinationModule __marketDestinationModule,
        BaseTOFTOptionsModule __optionsModule,
        BaseTOFTOptionsDestinationModule __optionsDestinationModule,
        BaseTOFTGenericModule __genericModule
    )
        BaseTOFTStorage(
            _lzEndpoint,
            _erc20,
            _yieldBox,
            _cluster,
            _name,
            _symbol,
            _decimal,
            _hostChainID
        )
        ERC20Permit(string(abi.encodePacked("TapiocaOFT-", _name)))
    {
        //Set modules
        _leverageModule = __leverageModule;
        _leverageDestinationModule = __leverageDestinationModule;

        _strategyModule = __strategyModule;
        _strategyDestinationModule = __strategyDestinationModule;

        _marketModule = __marketModule;
        _marketDestinationModule = __marketDestinationModule;

        _optionsModule = __optionsModule;
        _optionsDestinationModule = __optionsDestinationModule;

        _genericModule = __genericModule;

        //Set modules' addresses
        _moduleAddresses[Module.Generic] = payable(__genericModule);
        _moduleAddresses[Module.Options] = payable(__optionsModule);
        _moduleAddresses[Module.OptionsDestination] = payable(
            __optionsDestinationModule
        );
        _moduleAddresses[Module.Leverage] = payable(__leverageModule);
        _moduleAddresses[Module.LeverageDestination] = payable(
            __leverageDestinationModule
        );
        _moduleAddresses[Module.Market] = payable(__marketModule);
        _moduleAddresses[Module.MarketDestination] = payable(
            __marketDestinationModule
        );
        _moduleAddresses[Module.Strategy] = payable(__strategyModule);
        _moduleAddresses[Module.StrategyDestination] = payable(
            __strategyDestinationModule
        );

        //Set destination mappings
        _destinationMappings[PT_YB_SEND_STRAT] = DestinationCall({
            module: Module.StrategyDestination,
            functionSelector: BaseTOFTStrategyDestinationModule
                .strategyDeposit
                .selector
        });
        _destinationMappings[PT_YB_RETRIEVE_STRAT] = DestinationCall({
            module: Module.StrategyDestination,
            functionSelector: BaseTOFTStrategyDestinationModule
                .strategyWithdraw
                .selector
        });
        _destinationMappings[PT_MARKET_REMOVE_COLLATERAL] = DestinationCall({
            module: Module.MarketDestination,
            functionSelector: BaseTOFTMarketDestinationModule.remove.selector
        });
        _destinationMappings[PT_YB_SEND_SGL_BORROW] = DestinationCall({
            module: Module.MarketDestination,
            functionSelector: BaseTOFTMarketDestinationModule.borrow.selector
        });
        _destinationMappings[PT_MARKET_MULTIHOP_SELL] = DestinationCall({
            module: Module.LeverageDestination,
            functionSelector: BaseTOFTLeverageDestinationModule
                .multiHop
                .selector
        });
        _destinationMappings[PT_LEVERAGE_MARKET_DOWN] = DestinationCall({
            module: Module.LeverageDestination,
            functionSelector: BaseTOFTLeverageDestinationModule
                .leverageDown
                .selector
        });
        _destinationMappings[PT_TAP_EXERCISE] = DestinationCall({
            module: Module.OptionsDestination,
            functionSelector: BaseTOFTOptionsDestinationModule.exercise.selector
        });
        _destinationMappings[PT_SEND_FROM] = DestinationCall({
            module: Module.Generic,
            functionSelector: BaseTOFTGenericModule.sendFromDestination.selector
        });

        vault = new TOFTVault(_erc20);
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

    //----Leverage---
    /// @notice inits a multiHopSellCollateral call
    /// @param from The user who sells
    /// @param share Collateral YieldBox-shares to sell
    /// @param swapData Swap data used on destination chain for swapping USDO to the underlying TOFT token
    /// @param lzData LayerZero specific data
    /// @param externalData External contracts used for the cross chain operation
    /// @param airdropAdapterParams default or airdrop adapter params
    /// @param approvals array
    function initMultiSell(
        address from,
        uint256 share,
        IUSDOBase.ILeverageSwapData calldata swapData,
        IUSDOBase.ILeverageLZData calldata lzData,
        IUSDOBase.ILeverageExternalContractsData calldata externalData,
        bytes calldata airdropAdapterParams,
        ICommonData.IApproval[] memory approvals
    ) external payable {
        _executeModule(
            Module.Leverage,
            abi.encodeWithSelector(
                BaseTOFTLeverageModule.initMultiSell.selector,
                from,
                share,
                swapData,
                lzData,
                externalData,
                airdropAdapterParams,
                approvals
            ),
            false
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
            ),
            false
        );
    }

    //----Market---
    /// @notice calls removeCollateral on another layer
    /// @param from sending address
    /// @param to receiver address
    /// @param lzDstChainId LayerZero destination chain id
    /// @param zroPaymentAddress LayerZero ZRO payment address
    /// @param withdrawParams withdrawTo specific params
    /// @param removeParams removeAsset specific params
    /// @param approvals approvals specific params
    /// @param adapterParams LZ adapter params
    function removeCollateral(
        address from,
        address to,
        uint16 lzDstChainId,
        address zroPaymentAddress,
        ICommonData.IWithdrawParams calldata withdrawParams,
        ITapiocaOFT.IRemoveParams calldata removeParams,
        ICommonData.IApproval[] calldata approvals,
        bytes calldata adapterParams
    ) external payable {
        _executeModule(
            Module.Market,
            abi.encodeWithSelector(
                BaseTOFTMarketModule.removeCollateral.selector,
                from,
                to,
                lzDstChainId,
                zroPaymentAddress,
                withdrawParams,
                removeParams,
                approvals,
                adapterParams
            ),
            false
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
        ICommonData.IWithdrawParams calldata withdrawParams,
        ICommonData.ISendOptions calldata options,
        ICommonData.IApproval[] calldata approvals
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
            ),
            false
        );
    }

    //----Options---
    /// @notice Exercise an oTAP position
    /// @param optionsData oTap exerciseOptions data
    /// @param lzData data needed for the cross chain transer
    /// @param tapSendData needed for withdrawing Tap token
    /// @param approvals array
    function exerciseOption(
        ITapiocaOptionsBrokerCrossChain.IExerciseOptionsData
            calldata optionsData,
        ITapiocaOptionsBrokerCrossChain.IExerciseLZData calldata lzData,
        ITapiocaOptionsBrokerCrossChain.IExerciseLZSendTapData
            calldata tapSendData,
        ICommonData.IApproval[] calldata approvals,
        bytes calldata adapterParams
    ) external payable {
        _executeModule(
            Module.Options,
            abi.encodeWithSelector(
                BaseTOFTOptionsModule.exerciseOption.selector,
                optionsData,
                lzData,
                tapSendData,
                approvals,
                adapterParams
            ),
            false
        );
    }

    //----Strategy---
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
        uint256 assetId,
        uint16 lzDstChainId,
        ICommonData.ISendOptions calldata options
    ) external payable {
        _executeModule(
            Module.Strategy,
            abi.encodeWithSelector(
                BaseTOFTStrategyModule.sendToStrategy.selector,
                from,
                to,
                amount,
                assetId,
                lzDstChainId,
                options
            ),
            false
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
                assetId,
                lzDstChainId,
                zroPaymentAddress,
                airdropAdapterParam
            ),
            false
        );
    }

    //----Generic---
    /// @notice triggers a sendFrom to another layer from destination
    /// @param lzDstChainId LZ destination id
    /// @param airdropAdapterParams airdrop params
    /// @param zroPaymentAddress ZRO payment address
    /// @param amount amount to send back
    /// @param sendFromData data needed to trigger sendFrom on destination
    /// @param approvals approvals array
    function triggerSendFrom(
        uint16 lzDstChainId,
        bytes calldata airdropAdapterParams,
        address zroPaymentAddress,
        uint256 amount,
        ISendFrom.LzCallParams calldata sendFromData,
        ICommonData.IApproval[] calldata approvals
    ) external payable {
        _executeModule(
            Module.Options,
            abi.encodeWithSelector(
                BaseTOFTGenericModule.triggerSendFrom.selector,
                lzDstChainId,
                airdropAdapterParams,
                zroPaymentAddress,
                amount,
                sendFromData,
                approvals
            ),
            false
        );
    }

    /// @notice needed for Stargate Router to receive funds from Balancer.sol contract
    function sgReceive(
        uint16,
        bytes memory,
        uint,
        address,
        uint amountLD,
        bytes memory
    ) external override {
        if (erc20 == address(0)) {
            vault.depositNative{value: amountLD}();
        } else {
            IERC20(erc20).safeTransfer(address(vault), amountLD);
        }
    }

    // ************************ //
    // *** OWNER FUNCTIONS *** //
    // ************************ //
    /// @notice updates the cluster address
    /// @dev can only be called by the owner
    /// @param _cluster the new address
    function setCluster(ICluster _cluster) external {
        require(address(_cluster) != address(0), "TOFT_0");
        cluster = _cluster;
    }

    /// @notice rescues unused ETH from the contract
    /// @param amount the amount to rescue
    /// @param to the recipient
    function rescueEth(uint256 amount, address to) external onlyOwner {
        (bool success, ) = to.call{value: amount}("");
        require(success, "TOFT_Failed");
    }

    // ************************* //
    // *** PRIVATE FUNCTIONS *** //
    // ************************* //

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
            _spendAllowance(_fromAddress, msg.sender, _amount);
        }
        require(_amount > 0, "TOFT_0");
        IERC20(erc20).safeTransferFrom(_fromAddress, address(vault), _amount);
        _mint(_toAddress, _amount);
    }

    function _wrapNative(address _toAddress) internal virtual {
        vault.depositNative();
        _mint(_toAddress, msg.value);
    }

    function _unwrap(address _toAddress, uint256 _amount) internal virtual {
        _burn(msg.sender, _amount);
        vault.withdraw(_toAddress, _amount);
    }

    //---private---
    function _extractModule(Module _module) private view returns (address) {
        address module = _moduleAddresses[_module];
        require(module != address(0), "TOFT_module");
        return module;
    }

    function _executeModule(
        Module _module,
        bytes memory _data,
        bool _forwardRevert
    ) private returns (bool success, bytes memory returnData) {
        success = true;
        address module = _extractModule(_module);

        (success, returnData) = module.delegatecall(_data);
        if (!success && !_forwardRevert) {
            revert(_getRevertMsg(returnData));
        }
    }

    function _executeOnDestination(
        Module _module,
        bytes memory _data,
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) private {
        (bool success, bytes memory returnData) = _executeModule(
            _module,
            _data,
            true
        );
        if (!success) {
            _storeFailedMessage(
                _srcChainId,
                _srcAddress,
                _nonce,
                _payload,
                returnData
            );
        }
    }

    //---LZ---
    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) internal virtual override {
        uint256 packetType = _payload.toUint256(0);

        if (_destinationMappings[packetType].module != Module(0)) {
            DestinationCall memory callInfo = _destinationMappings[packetType];
            address targetModule;
            if (callInfo.module == Module.StrategyDestination) {
                targetModule = address(_strategyDestinationModule);
            } else if (callInfo.module == Module.MarketDestination) {
                targetModule = address(_marketDestinationModule);
            } else if (callInfo.module == Module.LeverageDestination) {
                targetModule = address(_leverageDestinationModule);
            } else if (callInfo.module == Module.OptionsDestination) {
                targetModule = address(_optionsDestinationModule);
            } else if (callInfo.module == Module.Generic) {
                targetModule = address(_genericModule);
            } else {
                targetModule = address(0);
            }

            _executeOnDestination(
                callInfo.module,
                abi.encodeWithSelector(
                    callInfo.functionSelector,
                    targetModule,
                    _srcChainId,
                    _srcAddress,
                    _nonce,
                    _payload
                ),
                _srcChainId,
                _srcAddress,
                _nonce,
                _payload
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
