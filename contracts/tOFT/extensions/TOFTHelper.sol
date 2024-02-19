// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// Tapioca
import {
    ITOFT,
    MarketBorrowMsg,
    MarketRemoveCollateralMsg,
    SendParamsMsg,
    ExerciseOptionsMsg,
    LeverageUpActionMsg
} from "tapioca-periph/interfaces/oft/ITOFT.sol";
import {
    TapiocaOmnichainEngineHelper,
    PrepareLzCallData,
    PrepareLzCallReturn,
    ComposeMsgData
} from "tapioca-periph/tapiocaOmnichainEngine/extension/TapiocaOmnichainEngineHelper.sol";
import {
    YieldBoxApproveAllMsg,
    MarketPermitActionMsg,
    YieldBoxApproveAssetMsg
} from "tapioca-periph/interfaces/periph/ITapiocaOmnichainEngine.sol";
import {TOFTMsgCodec} from "contracts/tOFT/libraries/TOFTMsgCodec.sol";
import {BaseTOFTTokenMsgType} from "../BaseTOFTTokenMsgType.sol";

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
     * @dev Sanitizes the message type to match one of the Tapioca supported ones.
     * @param _msgType The message type, custom ones with `PT_` as a prefix.
     */
    function _sanitizeMsgTypeExtended(uint16 _msgType) internal pure override returns (bool) {
        if (
            _msgType == MSG_MARKET_REMOVE_COLLATERAL || _msgType == MSG_YB_SEND_SGL_BORROW
                || _msgType == MSG_TAP_EXERCISE || _msgType == MSG_SEND_PARAMS || _msgType == MSG_LEVERAGE_UP
        ) {
            return true;
        }
        return false;
    }
}
