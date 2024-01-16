// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

// LZ
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import {BytesLib} from "@layerzerolabs/solidity-bytes-utils/contracts/BytesLib.sol";

// Tapioca
import {ITOFTv2, ERC20PermitApprovalMsg, ERC721PermitApprovalMsg, LZSendParam, YieldBoxApproveAllMsg, MarketPermitActionMsg} from "../ITOFTv2.sol";
import {ITapiocaOFT} from "tapioca-periph/contracts/interfaces/ITapiocaOFT.sol";
import {ICommonData} from "tapioca-periph/contracts/interfaces/ICommonData.sol";
import {MarketBorrowMsg} from "../modules/ITOFTv2Module.sol";

library TOFTMsgCoder {
    /**
     * @dev Option Builder offsets
     *
     * @dev !!!! The options are prepend by the `OptionBuilder.newOptions()` IF it's the first option.
     *
     * ------------------------------------------------------------- *
     * Name            | type     | start | end                      *
     * ------------------------------------------------------------- *
     * NEW_OPTION      | uint16   | 0     | 2                        *
     * ------------------------------------------------------------- *
     *
     * Single option structure, see `OptionsBuilder.addExecutorLzComposeOption`
     * ------------------------------------------------------------- *
     * Name            | type     | start | end  | comment           *
     * ------------------------------------------------------------- *
     * WORKER_ID       | uint8    | 2     | 3    |                   *
     * ------------------------------------------------------------- *
     * OPTION_LENGTH   | uint16   | 3     | 5    |                   *
     * ------------------------------------------------------------- *
     * OPTION_TYPE     | uint8    | 5     | 6    |                   *
     * ------------------------------------------------------------- *
     * INDEX           | uint16   | 6     | 8    |                   *
     * ------------------------------------------------------------- *
     * GAS             | uint128  | 8     | 24   |                   *
     * ------------------------------------------------------------- *
     * VALUE           | uint128  | 24    | 40   | Can be not packed *
     * ------------------------------------------------------------- *
     */
    uint16 internal constant OP_BLDR_EXECUTOR_WORKER_ID_ = 1; // ExecutorOptions.WORKER_ID
    uint16 internal constant OP_BLDR_WORKER_ID_OFFSETS = 2;
    uint16 internal constant OP_BLDR_OPTION_LENGTH_OFFSET = 3;
    uint16 internal constant OP_BLDR_OPTIONS_TYPE_OFFSET = 5;
    uint16 internal constant OP_BLDR_INDEX_OFFSET = 6;
    uint16 internal constant OP_BLDR_GAS_OFFSET = 8;
    uint16 internal constant OP_BLDR_VALUE_OFFSET = 24;

    // LZ message offsets
    uint8 internal constant LZ_COMPOSE_SENDER = 32;

    // TapOFTv2 receiver message offsets
    uint8 internal constant MSG_TYPE_OFFSET = 2;
    uint8 internal constant MSG_LENGTH_OFFSET = 4;
    uint8 internal constant MSG_INDEX_OFFSET = 6;

    /**
     *
     * @param _msgType The message type, either custom ones with `PT_` as a prefix, or default OFT ones.
     * @param _msgIndex The index of the compose message to encode.
     * @param _msg The Tap composed message.
     */
    function encodeTOFTComposeMsg(
        bytes memory _msg,
        uint16 _msgType,
        uint16 _msgIndex,
        bytes memory _toftComposeMsg
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                _toftComposeMsg,
                _msgType,
                uint16(_msg.length),
                _msgIndex,
                _msg
            );
    }

    /**
     * @notice Decodes a TapOFTv2 composed message. Used by the TapOFTv2 receiver.
     *
     *           *    TapOFTv2 message packet   *
     * ------------------------------------------------------------- *
     * Name          | type      | start | end                       *
     * ------------------------------------------------------------- *
     * msgType       | uint16    | 0     | 2                         *
     * ------------------------------------------------------------- *
     * msgLength     | uint16    | 2     | 4                         *
     * ------------------------------------------------------------- *
     * msgIndex      | uint16    | 4     | 6                         *
     * ------------------------------------------------------------- *
     * tapComposeMsg | bytes     | 6     | msglength + 6             *
     * ------------------------------------------------------------- *
     *
     * @param _msg The composed message for the send() operation.
     * @return msgType_ The message type. (TOFT proprietary `PT_` packets or LZ defaults).
     * @return msgLength_ The length of the message.
     * @return msgIndex_ The index of the current message.
     * @return tOFTComposeMsg_ The TOFT composed message, which is the actual message.
     * @return nextMsg_ The next composed message. If the message is not composed, it'll be empty.
     */
    function decodeTOFTComposeMsg(
        bytes memory _msg
    )
        internal
        pure
        returns (
            uint16 msgType_,
            uint16 msgLength_,
            uint16 msgIndex_,
            bytes memory tOFTComposeMsg_,
            bytes memory nextMsg_
        )
    {
        // TODO use bitwise operators?
        msgType_ = BytesLib.toUint16(BytesLib.slice(_msg, 0, 2), 0);
        msgLength_ = BytesLib.toUint16(
            BytesLib.slice(_msg, MSG_TYPE_OFFSET, 2),
            0
        );

        msgIndex_ = BytesLib.toUint16(
            BytesLib.slice(_msg, MSG_LENGTH_OFFSET, 2),
            0
        );
        tOFTComposeMsg_ = BytesLib.slice(_msg, MSG_INDEX_OFFSET, msgLength_);

        uint256 tOFTComposeOffset_ = MSG_INDEX_OFFSET + msgLength_;
        nextMsg_ = BytesLib.slice(
            _msg,
            tOFTComposeOffset_,
            _msg.length - (tOFTComposeOffset_)
        );
    }

    /**
     * @notice Decodes the index of a TapOFTv2 composed message.
     *
     * @param _msg The composed message for the send() operation.
     * @return msgIndex_ The index of the current message.
     */
    function decodeIndexOfTOFTComposeMsg(
        bytes memory _msg
    ) internal pure returns (uint16 msgIndex_) {
        return BytesLib.toUint16(BytesLib.slice(_msg, MSG_LENGTH_OFFSET, 2), 0);
    }

    /**
     * @notice Decodes the next message of a TapOFTv2 composed message, if any.
     * @param _msg The composed message for the send() operation.
     * @return nextMsg_ The next composed message. If the message is not composed, it'll be empty.
     */
    function decodeNextMsgOfTOFTCompose(
        bytes memory _msg
    ) internal pure returns (bytes memory nextMsg_) {
        uint16 msgLength_ = BytesLib.toUint16(
            BytesLib.slice(_msg, MSG_TYPE_OFFSET, 2),
            0
        );

        uint256 tOFTComposeOffset_ = MSG_INDEX_OFFSET + msgLength_;
        nextMsg_ = BytesLib.slice(
            _msg,
            tOFTComposeOffset_,
            _msg.length - (tOFTComposeOffset_)
        );
    }

    /**
     * @dev Decode LzCompose extra options message built by `OptionBuilder.addExecutorLzComposeOption()`.
     * @dev !!! IMPORTANT !!! It only works for options built only by `OptionBuilder.addExecutorLzComposeOption()`.
     *
     * @dev !!!! The options are prepend by the `OptionBuilder.newOptions()` IF it's the first option.
     * ------------------------------------------------------------- *
     * Name            | type     | start | end                      *
     * ------------------------------------------------------------- *
     * NEW_OPTION      | uint16   | 0     | 2                        *
     * ------------------------------------------------------------- *
     *
     * Single option structure, see `OptionsBuilder.addExecutorLzComposeOption`
     * ------------------------------------------------------------- *
     * Name            | type     | start | end  | comment           *
     * ------------------------------------------------------------- *
     * WORKER_ID       | uint8    | 2     | 3    |                   *
     * ------------------------------------------------------------- *
     * OPTION_LENGTH   | uint16   | 3     | 5    |                   *
     * ------------------------------------------------------------- *
     * OPTION_TYPE     | uint8    | 5     | 6    |                   *
     * ------------------------------------------------------------- *
     * INDEX           | uint16   | 6     | 8    |                   *
     * ------------------------------------------------------------- *
     * GAS             | uint128  | 8     | 24   |                   *
     * ------------------------------------------------------------- *
     * VALUE           | uint128  | 24    | 40   | Can be not packed *
     * ------------------------------------------------------------- *
     *
     * @param _options The extra options to be sanitized.
     */
    function decodeExtraOptions(
        bytes memory _options
    )
        internal
        pure
        returns (
            uint16 workerId_,
            uint16 optionLength_,
            uint16 optionType_,
            uint16 index_,
            uint128 gas_,
            uint128 value_,
            bytes memory nextMsg_
        )
    {
        workerId_ = BytesLib.toUint8(
            BytesLib.slice(_options, OP_BLDR_WORKER_ID_OFFSETS, 1),
            0
        );
        // If the workerId is not decoded correctly, it means option index != 0.
        if (workerId_ != OP_BLDR_EXECUTOR_WORKER_ID_) {
            // add the new options prefix
            _options = abi.encodePacked(OptionsBuilder.newOptions(), _options);
            workerId_ = OP_BLDR_EXECUTOR_WORKER_ID_;
        }

        /// @dev Option length is not the size of the actual `_options`, but the size of the option
        /// starting from `OPTION_TYPE`.
        optionLength_ = BytesLib.toUint16(
            BytesLib.slice(_options, OP_BLDR_OPTION_LENGTH_OFFSET, 2),
            0
        );
        optionType_ = BytesLib.toUint8(
            BytesLib.slice(_options, OP_BLDR_OPTIONS_TYPE_OFFSET, 1),
            0
        );
        index_ = BytesLib.toUint16(
            BytesLib.slice(_options, OP_BLDR_INDEX_OFFSET, 2),
            0
        );
        gas_ = BytesLib.toUint128(
            BytesLib.slice(_options, OP_BLDR_GAS_OFFSET, 16),
            0
        );

        /// @dev `value_` is not encoded if it's 0, check LZ `OptionBuilder.addExecutorLzComposeOption()`
        /// and `ExecutorOptions.encodeLzComposeOption()` for more info.
        /// 19 = OptionType (1) + Index (8) + Gas (16)
        if (optionLength_ == 19) {
            uint16 nextMsgOffset = OP_BLDR_VALUE_OFFSET; // 24
            if (_options.length > nextMsgOffset) {
                nextMsg_ = BytesLib.slice(
                    _options,
                    nextMsgOffset,
                    _options.length - nextMsgOffset
                );
            }
        }
        /// 35 = OptionType (1) + Index (8) + Gas (16) + Value (16)
        if (optionLength_ == 35) {
            value_ = BytesLib.toUint128(
                BytesLib.slice(_options, OP_BLDR_VALUE_OFFSET, 16),
                0
            );

            uint16 nextMsgOffset = OP_BLDR_VALUE_OFFSET + 16; // 24 + 16 = 40
            if (_options.length > nextMsgOffset) {
                nextMsg_ = BytesLib.slice(
                    _options,
                    nextMsgOffset,
                    _options.length - nextMsgOffset
                );
            }
        }
    }

    /**
     * @notice Decodes the length of extra options.
     *  @dev Option length is not the size of the actual `_options`, but the size of the option
     *  starting from `OPTION_TYPE`.
     */
    function decodeLengthOfExtraOptions(
        bytes memory _options
    ) internal pure returns (uint16 length_) {
        length_ = BytesLib.toUint16(
            BytesLib.slice(_options, OP_BLDR_OPTION_LENGTH_OFFSET, 2),
            0
        );
    }

    /**
     * @notice Decodes the index of extra options.
     */

    function decodeIndexOfExtraOptions(
        bytes memory _options
    ) internal pure returns (uint16 index_) {
        uint16 INDEX_OFFSET = 6;
        index_ = BytesLib.toUint16(
            BytesLib.slice(_options, INDEX_OFFSET, 2),
            0
        );
    }

    // /**
    //  * @notice Decodes the next message of extra options, if any.
    //  */
    // function decodeNextMsgOfExtraOptions(bytes memory _options) internal view returns (bytes memory nextMsg_) {
    //     uint16 OP_BLDR_GAS_OFFSET = 8;
    //     uint16 OP_BLDR_VALUE_OFFSET = 24;

    //     uint16 optionLength_ = decodeLengthOfExtraOptions(_options);
    //     console.log("optionLength_", optionLength_);

    //     /// @dev Value can be omitted if it's 0.
    //     /// check LZ `OptionBuilder.addExecutorLzComposeOption()` and `ExecutorOptions.encodeLzComposeOption()`
    //     /// 19 = OptionType (1) + Index (8) + Gas (16)
    //     if (optionLength_ == 19) {
    //         uint16 nextMsgOffset = OP_BLDR_GAS_OFFSET + 16; // 8 + 16 = 24
    //         console.log(nextMsgOffset);
    //         if (_options.length > nextMsgOffset) {
    //             nextMsg_ = BytesLib.slice(_options, nextMsgOffset, _options.length - nextMsgOffset);
    //         }
    //     }
    //     /// 35 = OptionType (1) + Index (8) + Gas (16) + Value (16)
    //     if (optionLength_ == 35) {
    //         uint16 nextMsgOffset = OP_BLDR_VALUE_OFFSET + 16; // 24 + 16 = 40
    //         if (_options.length > nextMsgOffset) {
    //             nextMsg_ = BytesLib.slice(_options, nextMsgOffset, _options.length - nextMsgOffset);
    //         }
    //     }
    // }

    /**
     * @notice Decode an OFT `_lzReceive()` message.
     *
     *          *    LzCompose message packet    *
     * ------------------------------------------------------------- *
     * Name           | type      | start | end                      *
     * ------------------------------------------------------------- *
     * composeSender  | bytes32   | 0     | 32                       *
     * ------------------------------------------------------------- *
     * oftComposeMsg_ | bytes     | 32    | _msg.Length              *
     * ------------------------------------------------------------- *
     *
     * @param _msg The composed message for the send() operation.
     * @return composeSender_ The address of the compose sender. (dst OApp).
     * @return oftComposeMsg_ The TapOFT composed message, which is the actual message.
     */
    function decodeLzComposeMsg(
        bytes calldata _msg
    )
        internal
        pure
        returns (address composeSender_, bytes memory oftComposeMsg_)
    {
        composeSender_ = OFTMsgCodec.bytes32ToAddress(
            bytes32(BytesLib.slice(_msg, 0, LZ_COMPOSE_SENDER))
        );

        oftComposeMsg_ = BytesLib.slice(
            _msg,
            LZ_COMPOSE_SENDER,
            _msg.length - LZ_COMPOSE_SENDER
        );
    }

    // ***************************************
    // * Encoding & Decoding TOFTv2 messages *
    // ***************************************

    //TODO: fill with custom packets decoding & encoding

    /**
     * @notice Encodes the message for the `TOFTv2Receiver._erc20PermitApprovalReceiver()` operation.
     */
    function buildERC20PermitApprovalMsg(
        ERC20PermitApprovalMsg memory _erc20PermitApprovalMsg
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                _erc20PermitApprovalMsg.token,
                _erc20PermitApprovalMsg.owner,
                _erc20PermitApprovalMsg.spender,
                _erc20PermitApprovalMsg.value,
                _erc20PermitApprovalMsg.deadline,
                _erc20PermitApprovalMsg.v,
                _erc20PermitApprovalMsg.r,
                _erc20PermitApprovalMsg.s
            );
    }

    /**
     * @notice Decodes an encoded message for the `TOFTv2Receiver.erc721PermitApprovalReceiver()` operation.
     */
    function decodeArrayOfERC721PermitApprovalMsg(
        bytes memory _msg
    ) internal pure returns (ERC721PermitApprovalMsg[] memory) {
        return abi.decode(_msg, (ERC721PermitApprovalMsg[]));
    }

    /**
     * @notice Decodes an encoded message for the `TOFTv2Receiver.erc20PermitApprovalReceiver()` operation.
     *
     *                    *   message packet   *
     * ------------------------------------------------------------- *
     * Name          | type      | start | end                       *
     * ------------------------------------------------------------- *
     * token         | address   | 0     | 20                        *
     * ------------------------------------------------------------- *
     * owner         | address   | 20    | 40                        *
     * ------------------------------------------------------------- *
     * spender       | address   | 40    | 60                        *
     * ------------------------------------------------------------- *
     * value         | uint256   | 60    | 92                        *
     * ------------------------------------------------------------- *
     * deadline      | uint256   | 92    | 124                       *
     * ------------------------------------------------------------- *
     * v             | uint8     | 124   | 125                       *
     * ------------------------------------------------------------- *
     * r             | bytes32   | 125   | 157                       *
     * ------------------------------------------------------------- *
     * s             | bytes32   | 157   | 189                       *
     * ------------------------------------------------------------- *
     *
     * @param _msg The encoded message. see `TOFTMsgCoder.buildERC20PermitApprovalMsg()`
     */
    struct __offsets {
        uint8 tokenOffset;
        uint8 ownerOffset;
        uint8 spenderOffset;
        uint8 valueOffset;
        uint8 deadlineOffset;
        uint8 vOffset;
        uint8 rOffset;
        uint8 sOffset;
    }

    function decodeERC20PermitApprovalMsg(
        bytes memory _msg
    )
        internal
        pure
        returns (ERC20PermitApprovalMsg memory erc20PermitApprovalMsg_)
    {
        // TODO bitwise operators ?
        __offsets memory offsets_ = __offsets({
            tokenOffset: 20,
            ownerOffset: 40,
            spenderOffset: 60,
            valueOffset: 92,
            deadlineOffset: 124,
            vOffset: 125,
            rOffset: 157,
            sOffset: 189
        });

        // Decoded data
        address token = BytesLib.toAddress(
            BytesLib.slice(_msg, 0, offsets_.tokenOffset),
            0
        );

        address owner = BytesLib.toAddress(
            BytesLib.slice(_msg, offsets_.tokenOffset, 20),
            0
        );

        address spender = BytesLib.toAddress(
            BytesLib.slice(_msg, offsets_.ownerOffset, 20),
            0
        );

        uint256 value = BytesLib.toUint256(
            BytesLib.slice(_msg, offsets_.spenderOffset, 32),
            0
        );

        uint256 deadline = BytesLib.toUint256(
            BytesLib.slice(_msg, offsets_.valueOffset, 32),
            0
        );

        uint8 v = uint8(
            BytesLib.toUint8(
                BytesLib.slice(_msg, offsets_.deadlineOffset, 1),
                0
            )
        );

        bytes32 r = BytesLib.toBytes32(
            BytesLib.slice(_msg, offsets_.vOffset, 32),
            0
        );

        bytes32 s = BytesLib.toBytes32(
            BytesLib.slice(_msg, offsets_.rOffset, 32),
            0
        );

        // Return structured data
        erc20PermitApprovalMsg_ = ERC20PermitApprovalMsg(
            token,
            owner,
            spender,
            value,
            deadline,
            v,
            r,
            s
        );
    }

    /**
     * @dev Decode an array of encoded messages for the `TOFTReceiver.erc20PermitApprovalReceiver()` operation.
     * @dev The message length must be a multiple of 189.
     *
     * @param _msg The encoded message. see `TOFTReceiver.buildERC20PermitApprovalMsg()`
     */
    function decodeArrayOfERC20PermitApprovalMsg(
        bytes memory _msg
    ) internal pure returns (ERC20PermitApprovalMsg[] memory) {
        /// @dev see `this.decodeERC20PermitApprovalMsg()`, token + owner + spender + value + deadline + v + r + s length = 189.
        uint256 msgCount_ = _msg.length / 189;

        ERC20PermitApprovalMsg[]
            memory erc20PermitApprovalMsgs_ = new ERC20PermitApprovalMsg[](
                msgCount_
            );

        uint256 msgIndex_;
        for (uint256 i; i < msgCount_; ) {
            erc20PermitApprovalMsgs_[i] = decodeERC20PermitApprovalMsg(
                BytesLib.slice(_msg, msgIndex_, 189)
            );
            unchecked {
                msgIndex_ += 189;
                ++i;
            }
        }

        return erc20PermitApprovalMsgs_;
    }

    /**
     * @notice Encodes the message for the `TOFTv2Receiver._yieldBoxRevokeAllReceiver()` operation.
     */
    function buildYieldBoxApproveAllMsg(
        YieldBoxApproveAllMsg memory _yieldBoxApprovalAllMsg
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                _yieldBoxApprovalAllMsg.target,
                _yieldBoxApprovalAllMsg.owner,
                _yieldBoxApprovalAllMsg.spender,
                _yieldBoxApprovalAllMsg.deadline,
                _yieldBoxApprovalAllMsg.v,
                _yieldBoxApprovalAllMsg.r,
                _yieldBoxApprovalAllMsg.s
            );
    }

    /**
     * @notice Encodes the message for the `TOFTv2Receiver._yieldBoxMarketPermitActionReceiver()` operation.
     */
    function buildMarketPermitApprovalMsg(
        MarketPermitActionMsg memory _marketApprovalMsg
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                _marketApprovalMsg.target,
                _marketApprovalMsg.actionType,
                _marketApprovalMsg.owner,
                _marketApprovalMsg.spender,
                _marketApprovalMsg.value,
                _marketApprovalMsg.deadline,
                _marketApprovalMsg.v,
                _marketApprovalMsg.r,
                _marketApprovalMsg.s
            );
    }

    struct __marketOffsets {
        uint8 targetOffset;
        uint8 actionTypeOffset;
        uint8 ownerOffset;
        uint8 spenderOffset;
        uint8 valueOffset;
        uint8 deadlineOffset;
        uint8 vOffset;
        uint8 rOffset;
        uint8 sOffset;
    }

    /**
     * @notice Decodes an encoded message for the `TOFTv2Receiver.marketPermitActionReceiver()` operation.
     *
     *                    *   message packet   *
     * ------------------------------------------------------------- *
     * Name          | type      | start | end                       *
     * ------------------------------------------------------------- *
     * target        | address   | 0     | 20                        *
     * ------------------------------------------------------------- *
     * actionType    | address   | 20    | 22                       *
     * ------------------------------------------------------------- *
     * owner         | address   | 22    | 42                        *
     * ------------------------------------------------------------- *
     * spender       | address   | 42    | 62                        *
     * ------------------------------------------------------------- *
     * value         | address   | 62    | 94                        *
     * ------------------------------------------------------------- *
     * deadline      | uint256   | 94   | 126                        *
     * ------------------------------------------------------------- *
     * v             | uint8     | 126  | 127                        *
     * ------------------------------------------------------------- *
     * r             | bytes32   | 127  | 159                        *
     * ------------------------------------------------------------- *
     * s             | bytes32   | 159  | 191                       *
     * ------------------------------------------------------------- *
     *
     * @param _msg The encoded message. see `TOFTMsgCoder.buildMarketPermitApprovalMsg()`
     */
    function decodeMarketPermitApprovalMsg(
        bytes memory _msg
    )
        internal
        pure
        returns (MarketPermitActionMsg memory marketPermitActionMsg_)
    {
        __marketOffsets memory offsets_ = __marketOffsets({
            targetOffset: 20,
            actionTypeOffset: 22,
            ownerOffset: 42,
            spenderOffset: 62,
            valueOffset: 94,
            deadlineOffset: 126,
            vOffset: 127,
            rOffset: 159,
            sOffset: 191
        });

        // Decoded data
        address target = BytesLib.toAddress(
            BytesLib.slice(_msg, 0, offsets_.targetOffset),
            0
        );

        uint16 actionType = uint16(
            BytesLib.toUint16(BytesLib.slice(_msg, offsets_.targetOffset, 2), 0)
        );

        address owner = BytesLib.toAddress(
            BytesLib.slice(_msg, offsets_.actionTypeOffset, 20),
            0
        );

        address spender = BytesLib.toAddress(
            BytesLib.slice(_msg, offsets_.ownerOffset, 20),
            0
        );

        uint256 value = BytesLib.toUint256(
            BytesLib.slice(_msg, offsets_.spenderOffset, 32),
            0
        );

        uint256 deadline = BytesLib.toUint256(
            BytesLib.slice(_msg, offsets_.valueOffset, 32),
            0
        );

        uint8 v = uint8(
            BytesLib.toUint8(
                BytesLib.slice(_msg, offsets_.deadlineOffset, 1),
                0
            )
        );

        bytes32 r = BytesLib.toBytes32(
            BytesLib.slice(_msg, offsets_.vOffset, 32),
            0
        );

        bytes32 s = BytesLib.toBytes32(
            BytesLib.slice(_msg, offsets_.rOffset, 32),
            0
        );

        // Return structured data
        marketPermitActionMsg_ = MarketPermitActionMsg(
            target,
            actionType,
            owner,
            spender,
            value,
            deadline,
            v,
            r,
            s
        );
    }

    struct __ybOffsets {
        uint8 targetOffset;
        uint8 ownerOffset;
        uint8 spenderOffset;
        uint8 deadlineOffset;
        uint8 vOffset;
        uint8 rOffset;
        uint8 sOffset;
    }

    /**
     * @notice Decodes an encoded message for the `TOFTv2Receiver.ybPermitAll()` operation.
     *
     *                    *   message packet   *
     * ------------------------------------------------------------- *
     * Name          | type      | start | end                       *
     * ------------------------------------------------------------- *
     * target        | address   | 0     | 20                        *
     * ------------------------------------------------------------- *
     * owner         | address   | 20    | 40                        *
     * ------------------------------------------------------------- *
     * spender       | address   | 40    | 60                        *
     * ------------------------------------------------------------- *
     * deadline      | uint256   | 60   | 92                         *
     * ------------------------------------------------------------- *
     * v             | uint8     | 92   | 93                         *
     * ------------------------------------------------------------- *
     * r             | bytes32   | 93   | 125                        *
     * ------------------------------------------------------------- *
     * s             | bytes32   | 125   | 157                       *
     * ------------------------------------------------------------- *
     *
     * @param _msg The encoded message. see `TOFTMsgCoder.buildYieldBoxPermitAll()`
     */
    function decodeYieldBoxApproveAllMsg(
        bytes memory _msg
    ) internal pure returns (YieldBoxApproveAllMsg memory ybPermitAllMsg_) {
        __ybOffsets memory offsets_ = __ybOffsets({
            targetOffset: 20,
            ownerOffset: 72,
            spenderOffset: 92,
            deadlineOffset: 124,
            vOffset: 125,
            rOffset: 157,
            sOffset: 189
        });

        // Decoded data
        address target = BytesLib.toAddress(
            BytesLib.slice(_msg, 0, offsets_.targetOffset),
            0
        );

        address owner = BytesLib.toAddress(
            BytesLib.slice(_msg, offsets_.targetOffset, 20),
            0
        );

        address spender = BytesLib.toAddress(
            BytesLib.slice(_msg, offsets_.ownerOffset, 20),
            0
        );

        uint256 deadline = BytesLib.toUint256(
            BytesLib.slice(_msg, offsets_.spenderOffset, 32),
            0
        );

        uint8 v = uint8(
            BytesLib.toUint8(
                BytesLib.slice(_msg, offsets_.deadlineOffset, 1),
                0
            )
        );

        bytes32 r = BytesLib.toBytes32(
            BytesLib.slice(_msg, offsets_.vOffset, 32),
            0
        );

        bytes32 s = BytesLib.toBytes32(
            BytesLib.slice(_msg, offsets_.rOffset, 32),
            0
        );

        // Return structured data
        ybPermitAllMsg_ = YieldBoxApproveAllMsg(
            target,
            owner,
            spender,
            deadline,
            v,
            r,
            s
        );
    }

    /**
     * @notice Encodes the message for the `TOFTv2MarketReceiverModule.borrow()` operation.
     */
    function buildMarketBorrow(
        MarketBorrowMsg memory _marketBorrowMsg
    ) internal pure returns (bytes memory) {
        return abi.encode(_marketBorrowMsg);
    }

    /**
     * @notice Decodes an encoded message for the `TOFTv2MarketReceiverModule.borrow()` operation.
     */
    function decodeMarketBorrowMsg(
        bytes memory _msg
    ) internal pure returns (MarketBorrowMsg memory marketBorrowMsg_) {
        return abi.decode(_msg, (MarketBorrowMsg));
    }
}
