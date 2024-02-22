// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";

// External
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Tapioca
import {
    PrepareLzCallData,
    PrepareLzCallReturn,
    ComposeMsgData
} from "tapioca-periph/tapiocaOmnichainEngine/extension/TapiocaOmnichainEngineHelper.sol";
import {TapiocaOmnichainEngineHelper} from
    "tapioca-periph/tapiocaOmnichainEngine/extension/TapiocaOmnichainEngineHelper.sol";
import {
    IMagnetar,
    DepositAddCollateralAndBorrowFromMarketData,
    MagnetarWithdrawData,
    MagnetarCall,
    MagnetarModule,
    MagnetarAction
} from "tapioca-periph/interfaces/periph/IMagnetar.sol";
import {ITapiocaOmnichainEngine, LZSendParam} from "tapioca-periph/interfaces/periph/ITapiocaOmnichainEngine.sol";
import {PearlmitHandler, IPearlmit} from "tapioca-periph/pearlmit/PearlmitHandler.sol";
import {IMarketHelper} from "tapioca-periph/interfaces/bar/IMarketHelper.sol";
import {IPermitAll} from "tapioca-periph/interfaces/common/IPermitAll.sol";
import {IYieldBox} from "tapioca-periph/interfaces/yieldbox/IYieldBox.sol";
import {IMarket, Module} from "tapioca-periph/interfaces/bar/IMarket.sol";
import {IOftSender} from "tapioca-periph/interfaces/oft/IOftSender.sol";
import {ICluster} from "tapioca-periph/interfaces/periph/ICluster.sol";
import {IPermit} from "tapioca-periph/interfaces/common/IPermit.sol";

/*
* @dev need this because of via-ir: true error on original Magnetar
**/
contract MagnetarMock is PearlmitHandler {
    using SafeCast for uint256;
    using SafeERC20 for IERC20;

    error MagnetarMock_NotAuthorized();
    error MagnetarMock_Failed();
    error MagnetarMock_TargetNotWhitelisted(address target);
    error MagnetarMock_GasMismatch(uint256 expected, uint256 received);
    error MagnetarMock_UnknownReason();
    error MagnetarMock_ActionNotValid(MagnetarAction action, bytes actionCalldata); // Burst did not find what to execute

    ICluster public cluster;

    constructor(address _cluster, IPearlmit _pearlmit) PearlmitHandler(_pearlmit) {
        cluster = ICluster(_cluster);
    }

    function burst(MagnetarCall[] calldata calls) external payable {
        uint256 valAccumulator;

        uint256 length = calls.length;

        for (uint256 i; i < length; i++) {
            MagnetarCall calldata _action = calls[i];
            if (!_action.allowFailure) {
                require(
                    _action.call.length > 0,
                    string.concat("Magnetar: Missing call for action with index", string(abi.encode(i)))
                );
            }
            valAccumulator += _action.value;

            /// @dev Permit on YB, or an SGL/BB market
            if (_action.id == MagnetarAction.Permit) {
                _processPermitOperation(_action.target, _action.call, _action.allowFailure);
                continue; // skip the rest of the loop
            }

            /// @dev Wrap/unwrap singular operations
            if (_action.id == MagnetarAction.Wrap) {
                continue; // skip the rest of the loop
            }

            /// @dev Market singular operations
            if (_action.id == MagnetarAction.Market) {
                continue; // skip the rest of the loop
            }

            /// @dev Tap singular operations
            if (_action.id == MagnetarAction.TapToken) {
                continue; // skip the rest of the loop
            }

            /// @dev Modules will not return result data.
            if (_action.id == MagnetarAction.AssetModule) {
                _executeModule(MagnetarModule.YieldBoxModule, _action.call);
                continue; // skip the rest of the loop
            }

            /// @dev Modules will not return result data.
            if (_action.id == MagnetarAction.CollateralModule) {
                _executeModule(MagnetarModule.CollateralModule, _action.call);
                continue; // skip the rest of the loop
            }

            /// @dev Modules will not return result data.
            if (_action.id == MagnetarAction.MintModule) {
                _executeModule(MagnetarModule.MintModule, _action.call);
                continue; // skip the rest of the loop
            }

            /// @dev Modules will not return result data.
            if (_action.id == MagnetarAction.MintXChainModule) {
                _executeModule(MagnetarModule.MintXChainModule, _action.call);
                continue; // skip the rest of the loop
            }

            /// @dev Modules will not return result data.
            if (_action.id == MagnetarAction.OptionModule) {
                _executeModule(MagnetarModule.OptionModule, _action.call);
                continue; // skip the rest of the loop
            }

            /// @dev Modules will not return result data.
            if (_action.id == MagnetarAction.YieldBoxModule) {
                _executeModule(MagnetarModule.YieldBoxModule, _action.call);
                continue; // skip the rest of the loop
            }
        }
    }

    /**
     * @dev Process a permit operation, will only execute if the selector is allowed.
     * @dev !!! WARNING !!! Make sure to check the Owner param and check that function definition didn't change.
     *
     * @param _target The contract address to call.
     * @param _actionCalldata The calldata to send to the target.
     * @param _allowFailure Whether to allow the call to fail.
     */
    function _processPermitOperation(address _target, bytes calldata _actionCalldata, bool _allowFailure) private {
        /// @dev owner address should always be first param.
        // permitAction(bytes,uint16)
        // permit(address owner...)
        // revoke(address owner...)
        // permitAll(address from,..)
        // permit(address from,...)
        // setApprovalForAll(address from,...)
        // setApprovalForAsset(address from,...)
        bytes4 funcSig = bytes4(_actionCalldata[:4]);
        if (
            funcSig == IPermitAll.permitAll.selector || funcSig == IPermitAll.revokeAll.selector
                || funcSig == IPermit.permit.selector || funcSig == IPermit.revoke.selector
                || funcSig == IYieldBox.setApprovalForAll.selector || funcSig == IYieldBox.setApprovalForAsset.selector
        ) {
            /// @dev Owner param check. See Warning above.
            _checkSender(abi.decode(_actionCalldata[4:36], (address)));
            // No need to send value on permit
            _executeCall(_target, _actionCalldata, 0, _allowFailure);
            return;
        }
        revert MagnetarMock_ActionNotValid(MagnetarAction.Permit, _actionCalldata);
    }

    function depositAddCollateralAndBorrowFromMarket(DepositAddCollateralAndBorrowFromMarketData memory _data)
        external
        payable
    {
        if (!cluster.isWhitelisted(cluster.lzChainId(), address(_data.market))) revert MagnetarMock_NotAuthorized();

        IYieldBox yieldBox = IYieldBox(IMarket(_data.market).yieldBox());

        uint256 collateralId = IMarket(_data.market).collateralId();
        (, address collateralAddress,,) = yieldBox.assets(collateralId);

        uint256 _share = yieldBox.toShare(collateralId, _data.collateralAmount, false);

        //deposit to YieldBox
        if (_data.deposit) {
            // transfers tokens from sender or from the user to this contract
            _data.collateralAmount = _extractTokens(_data.user, collateralAddress, _data.collateralAmount);
            _share = yieldBox.toShare(collateralId, _data.collateralAmount, false);

            // deposit to YieldBox
            IERC20(collateralAddress).approve(address(yieldBox), 0);
            IERC20(collateralAddress).approve(address(yieldBox), _data.collateralAmount);
            yieldBox.depositAsset(collateralId, address(this), address(this), _data.collateralAmount, 0);
        }

        // performs .addCollateral on market
        if (_data.collateralAmount > 0) {
            yieldBox.setApprovalForAll(address(_data.market), true);
            (Module[] memory modules, bytes[] memory calls) = IMarketHelper(_data.marketHelper).addCollateral(
                _data.deposit ? address(this) : _data.user, _data.user, false, _data.collateralAmount, _share
            );
            IMarket(_data.market).execute(modules, calls, true);
        }

        // performs .borrow on market
        // if `withdraw` it uses `withdrawTo` to withdraw assets on the same chain or to another one
        if (_data.borrowAmount > 0) {
            address borrowReceiver = _data.withdrawParams.withdraw ? address(this) : _data.user;
            (Module[] memory modules, bytes[] memory calls) =
                IMarketHelper(_data.marketHelper).borrow(_data.user, borrowReceiver, _data.borrowAmount);
            IMarket(_data.market).execute(modules, calls, true);

            if (_data.withdrawParams.withdraw) {
                _withdrawToChain(_data.withdrawParams);
            }
        }

        yieldBox.setApprovalForAll(address(_data.market), false);
    }

    function withdrawToChain(MagnetarWithdrawData memory data) external payable {
        _withdrawToChain(data);
    }

    /**
     * @dev Executes a call to an address, optionally reverting on failure. Make sure to sanitize prior to calling.
     */
    function _executeCall(address _target, bytes calldata _actionCalldata, uint256 _actionValue, bool _allowFailure)
        private
    {
        bool success;
        bytes memory returnData;

        if (_actionValue > 0) {
            (success, returnData) = _target.call{value: _actionValue}(_actionCalldata);
        } else {
            (success, returnData) = _target.call(_actionCalldata);
        }

        if (!success && !_allowFailure) {
            _getRevertMsg(returnData);
        }
    }

    function _checkSender(address _from) internal view {
        if (_from != msg.sender && !cluster.isWhitelisted(0, msg.sender)) {
            revert MagnetarMock_NotAuthorized();
        }
    }

    function _withdrawToChain(MagnetarWithdrawData memory data) private {
        if (!cluster.isWhitelisted(0, address(data.yieldBox))) {
            revert MagnetarMock_TargetNotWhitelisted(address(data.yieldBox));
        }
        IYieldBox _yieldBox = IYieldBox(data.yieldBox);

        // perform a same chain withdrawal
        if (data.lzSendParams.sendParam.dstEid == 0) {
            _withdrawHere(_yieldBox, data.assetId, data.lzSendParams.sendParam.to, data.lzSendParams.sendParam.amountLD);
            return;
        }

        if (msg.value > 0) {
            if (msg.value != data.composeGas) revert MagnetarMock_GasMismatch(data.composeGas, msg.value);
        }

        // perform a cross chain withdrawal
        (, address asset,,) = _yieldBox.assets(data.assetId);
        if (!cluster.isWhitelisted(0, asset)) {
            revert MagnetarMock_TargetNotWhitelisted(asset);
        }

        _yieldBox.withdraw(data.assetId, address(this), address(this), data.lzSendParams.sendParam.amountLD, 0);
        // TODO: decide about try-catch here
        if (data.unwrap) {
            _lzCustomWithdraw(
                asset,
                data.lzSendParams,
                data.sendGas,
                data.sendVal,
                data.composeGas,
                data.composeVal,
                data.composeMsgType
            );
        } else {
            _lzWithdraw(asset, data.lzSendParams, data.sendGas, data.sendVal);
        }
    }

    function _extractTokens(address _from, address _token, uint256 _amount) private returns (uint256) {
        uint256 balanceBefore = IERC20(_token).balanceOf(address(this));
        // IERC20(_token).safeTransferFrom(_from, address(this), _amount);
        bool isErr = pearlmit.transferFromERC20(_from, address(this), _token, _amount);
        if (isErr) revert MagnetarMock_NotAuthorized();
        uint256 balanceAfter = IERC20(_token).balanceOf(address(this));
        if (balanceAfter <= balanceBefore) revert MagnetarMock_Failed();
        return balanceAfter - balanceBefore;
    }

    function _withdrawHere(IYieldBox _yieldBox, uint256 _assetId, bytes32 _to, uint256 _amount) private {
        _yieldBox.withdraw(_assetId, address(this), OFTMsgCodec.bytes32ToAddress(_to), _amount, 0);
    }

    function _lzWithdraw(address _asset, LZSendParam memory _lzSendParam, uint128 _lzSendGas, uint128 _lzSendVal)
        private
    {
        PrepareLzCallReturn memory prepareLzCallReturn = _prepareLzSend(_asset, _lzSendParam, _lzSendGas, _lzSendVal);

        if (msg.value < prepareLzCallReturn.msgFee.nativeFee) {
            revert MagnetarMock_GasMismatch(prepareLzCallReturn.msgFee.nativeFee, msg.value);
        }

        IOftSender(_asset).sendPacket{value: prepareLzCallReturn.msgFee.nativeFee}(
            prepareLzCallReturn.lzSendParam, prepareLzCallReturn.composeMsg
        );
    }

    function _lzCustomWithdraw(
        address _asset,
        LZSendParam memory _lzSendParam,
        uint128 _lzSendGas,
        uint128 _lzSendVal,
        uint128 _lzComposeGas,
        uint128 _lzComposeVal,
        uint16 _lzComposeMsgType
    ) private {
        PrepareLzCallReturn memory prepareLzCallReturn = _prepareLzSend(_asset, _lzSendParam, _lzSendGas, _lzSendVal);

        TapiocaOmnichainEngineHelper _toeHelper = new TapiocaOmnichainEngineHelper();
        PrepareLzCallReturn memory prepareLzCallReturn2 = _toeHelper.prepareLzCall(
            ITapiocaOmnichainEngine(_asset),
            PrepareLzCallData({
                dstEid: _lzSendParam.sendParam.dstEid,
                recipient: _lzSendParam.sendParam.to,
                amountToSendLD: 0,
                minAmountToCreditLD: 0,
                msgType: _lzComposeMsgType,
                composeMsgData: ComposeMsgData({
                    index: 0,
                    gas: _lzComposeGas,
                    value: prepareLzCallReturn.msgFee.nativeFee.toUint128(),
                    data: _lzSendParam.sendParam.composeMsg,
                    prevData: bytes(""),
                    prevOptionsData: bytes("")
                }),
                lzReceiveGas: _lzSendGas + _lzComposeGas,
                lzReceiveValue: _lzComposeVal
            })
        );

        if (msg.value < prepareLzCallReturn2.msgFee.nativeFee) {
            revert MagnetarMock_GasMismatch(prepareLzCallReturn2.msgFee.nativeFee, msg.value);
        }

        IOftSender(_asset).sendPacket{value: prepareLzCallReturn2.msgFee.nativeFee}(
            prepareLzCallReturn2.lzSendParam, prepareLzCallReturn2.composeMsg
        );
    }

    function _prepareLzSend(address _asset, LZSendParam memory _lzSendParam, uint128 _lzSendGas, uint128 _lzSendVal)
        private
        returns (PrepareLzCallReturn memory prepareLzCallReturn)
    {
        TapiocaOmnichainEngineHelper _toeHelper = new TapiocaOmnichainEngineHelper();
        prepareLzCallReturn = _toeHelper.prepareLzCall(
            ITapiocaOmnichainEngine(_asset),
            PrepareLzCallData({
                dstEid: _lzSendParam.sendParam.dstEid,
                recipient: _lzSendParam.sendParam.to,
                amountToSendLD: _lzSendParam.sendParam.amountLD,
                minAmountToCreditLD: _lzSendParam.sendParam.minAmountLD,
                msgType: 1, // SEND
                composeMsgData: ComposeMsgData({
                    index: 0,
                    gas: 0,
                    value: 0,
                    data: bytes(""),
                    prevData: bytes(""),
                    prevOptionsData: bytes("")
                }),
                lzReceiveGas: _lzSendGas,
                lzReceiveValue: _lzSendVal
            })
        );
    }

    function _executeModule(MagnetarModule, bytes memory _data) internal returns (bytes memory returnData) {
        bool success = true;

        (success, returnData) = address(this).delegatecall(_data);
        if (!success) {
            _getRevertMsg(returnData);
        }
    }

    function _getRevertMsg(bytes memory _returnData) internal pure {
        // If the _res length is less than 68, then
        // the transaction failed with custom error or silently (without a revert message)
        if (_returnData.length < 68) revert MagnetarMock_UnknownReason();

        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        revert(abi.decode(_returnData, (string))); // All that remains is the revert string
    }
}
