// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {SendParam, MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

// Tapioca
import {LZSendParam} from "contracts/ITOFTv2.sol";

/**
 * @notice Used to build the TAP compose messages.
 */
struct ComposeMsgData {
    uint8 index; // The index of the message.
    uint128 gas; // The gasLimit used on the compose() function in the OApp for this message.
    uint128 value; // The msg.value passed to the compose() function in the OApp for this message.
    bytes data; // The data of the message.
    bytes prevData; // The previous compose msg data, if any. Used to aggregate the compose msg data.
    bytes prevOptionsData; // The previous compose msg options data, if any. Used to aggregate  the compose msg options.
}

/**
 * @notice Used to prepare an LZ call. See `TapOFTv2Helper.prepareLzCall()`.
 */
struct PrepareLzCallData {
    uint32 dstEid; // The destination endpoint ID.
    address refundAddress; // The refund address;
    bytes32 recipient; // The recipient address. Receiver of the OFT send if any, and refund address for the LZ send.
    uint256 amountToSendLD; // The amount to send in the OFT send. If any.
    uint256 minAmountToCreditLD; // The min amount to credit in the OFT send. If any.
    uint16 msgType; // The message type, TAP custom ones, with `PT_` as a prefix.
    ComposeMsgData composeMsgData; // The compose msg data.
    uint128 lzReceiveGas; // The gasLimit used on the lzReceive() function in the OApp.
    uint128 lzReceiveValue; // The msg.value passed to the lzReceive() function in the OApp.
}

/**
 * @notice Used to return the result of the `TapOFTv2Helper.prepareLzCall()` function.
 */
struct PrepareLzCallReturn {
    bytes composeMsg; // The composed message. Can include previous composeMsg if any.
    bytes composeOptions; // The options of the composeMsg. Single option container, not aggregated with previous composeMsgOptions.
    SendParam sendParam; // OFT basic Tx params.
    MessagingFee msgFee; // OFT msg fee, include aggregation of previous composeMsgOptions.
    LZSendParam lzSendParam; // LZ Tx params. contains multiple information for the Tapioca `sendPacket()` call.
    bytes oftMsgOptions; // OFT msg options, include aggregation of previous composeMsgOptions.
}
