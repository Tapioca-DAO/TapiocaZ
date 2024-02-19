// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

// Tapioca
import {
    ITOFT,
    YieldBoxApproveAllMsg,
    MarketPermitActionMsg,
    MarketBorrowMsg,
    MarketRemoveCollateralMsg,
    SendParamsMsg,
    ExerciseOptionsMsg,
    YieldBoxApproveAssetMsg,
    LeverageUpActionMsg
} from "tapioca-periph/interfaces/oft/ITOFT.sol";
import {
    TapiocaOmnichainEngineHelper,
    PrepareLzCallData,
    PrepareLzCallReturn,
    ComposeMsgData
} from "tapioca-periph/tapiocaOmnichainEngine/extension/TapiocaOmnichainEngineHelper.sol";
import {BaseTOFTTokenMsgType} from "../BaseTOFTTokenMsgType.sol";
import {TOFTMsgCodec} from "contracts/tOFT/libraries/TOFTMsgCodec.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

contract TOFTHelper is TapiocaOmnichainEngineHelper, BaseTOFTTokenMsgType {
    /// =======================
    /// Builder functions
    /// =======================
     /**
     * @notice Encodes the message for the PT_SEND_PARAMS operation.
     *
     */
    function buildLeverageUpMsg(LeverageUpActionMsg calldata _msg) public pure returns (bytes memory) {
        return TOFTMsgCodec.buildLeverageUpMsg(_msg);
    }
    /**
     * @notice Encodes the message for the exercise options operation.
     *
     */
    function buildExerciseOptionMsg(ExerciseOptionsMsg calldata _msg) public pure returns (bytes memory) {
        return TOFTMsgCodec.buildExerciseOptionsMsg(_msg);
    }

    /**
     * @notice Encodes the message for the PT_SEND_PARAMS operation.
     *
     */
    function buildSendWithParamsMsg(SendParamsMsg calldata _msg) public pure returns (bytes memory) {
        return TOFTMsgCodec.buildSendParamsMsg(_msg);
    }


    /**
     * @notice Encodes the message for the PT_YB_SEND_SGL_BORROW operation.
     *
     */
    function buildMarketRemoveCollateralMsg(MarketRemoveCollateralMsg calldata _marketMsg)
        public
        pure
        returns (bytes memory)
    {
        return TOFTMsgCodec.buildMarketRemoveCollateralMsg(_marketMsg);
    }

    /**
     * @notice Encodes the message for the PT_YB_SEND_SGL_BORROW operation.
     *
     */
    function buildMarketBorrowMsg(MarketBorrowMsg calldata _marketBorrowMsg) public pure returns (bytes memory) {
        return TOFTMsgCodec.buildMarketBorrow(_marketBorrowMsg);
    }

    /**
     * @notice Encode the message for the _marketPermitBorrowReceiver() & _marketPermitLendReceiver operations.
     * @param _marketPermitActionMsg The Market permit lend/borrow approval message.
     */
    function buildMarketPermitApprovalMsg(MarketPermitActionMsg memory _marketPermitActionMsg)
        public
        pure
        returns (bytes memory msg_)
    {
        msg_ = TOFTMsgCodec.buildMarketPermitApprovalMsg(_marketPermitActionMsg);
    }

    /**
     * @notice Encode the message for the _yieldBoxPermitAllReceiver() & _yieldBoxRevokeAllReceiver operations.
     * @param _yieldBoxApprovalAllMsg The YieldBox permit/revoke approval message.
     */
    function buildYieldBoxApproveAllMsg(YieldBoxApproveAllMsg memory _yieldBoxApprovalAllMsg)
        public
        pure
        returns (bytes memory msg_)
    {
        msg_ = TOFTMsgCodec.buildYieldBoxApproveAllMsg(_yieldBoxApprovalAllMsg);
    }

    /**
     * @notice Encode the message for the `PT_YB_APPROVE_ASSET` operation,
     *   _yieldBoxRevokeAssetReceiver() & _yieldBoxApproveAssetReceiver operations.
     * @param _approvalMsg The YieldBoxApproveAssetMsg messages.
     */
    function buildYieldBoxApproveAssetMsg(YieldBoxApproveAssetMsg[] memory _approvalMsg)
        public
        pure
        returns (bytes memory msg_)
    {
        uint256 approvalsLength = _approvalMsg.length;
        for (uint256 i; i < approvalsLength;) {
            msg_ = abi.encodePacked(msg_, TOFTMsgCodec.buildYieldBoxPermitAssetMsg(_approvalMsg[i]));
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Sanitizes the message type to match one of the Tapioca supported ones.
     * @param _msgType The message type, custom ones with `PT_` as a prefix.
     */
    function _sanitizeMsgTypeExtended(uint16 _msgType) internal pure override returns (bool) {
        if (
            _msgType == MSG_YB_APPROVE_ASSET || _msgType == MSG_YB_APPROVE_ALL || _msgType == MSG_MARKET_PERMIT
                || _msgType == MSG_MARKET_REMOVE_COLLATERAL || _msgType == MSG_YB_SEND_SGL_BORROW
                || _msgType == MSG_TAP_EXERCISE || _msgType == MSG_SEND_PARAMS || _msgType == MSG_LEVERAGE_UP
        ) {
            return true;
        }
        return false;
    }
}
