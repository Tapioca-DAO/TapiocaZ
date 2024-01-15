// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {SendParam, MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

// Tapioca
import {ITapiocaOFT} from "tapioca-periph/contracts/interfaces/ITapiocaOFT.sol";
import {ICommonData} from "tapioca-periph/contracts/interfaces/ICommonData.sol";

interface ITOFTv2Module {}

/**
 * @notice Encodes the message for the PT_YB_SEND_SGL_BORROW operation.
 */
struct MarketBorrowMsg {
    address from;
    address to;
    ITapiocaOFT.IBorrowParams borrowParams;
    ICommonData.IWithdrawParams withdrawParams;
    ICommonData.ISendOptions options;
    ICommonData.IApproval[] approvals;
    ICommonData.IApproval[] revokes;
}
