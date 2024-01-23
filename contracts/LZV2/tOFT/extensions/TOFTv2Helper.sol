// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {
    SendParam,
    MessagingFee,
    MessagingReceipt,
    OFTReceipt
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";

// External
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {TOFTMsgCoder} from "contracts/libraries/TOFTMsgCoder.sol";
import {
    ITOFTv2,
    LZSendParam,
    ERC20PermitApprovalMsg,
    ERC20PermitApprovalMsg,
    LZSendParam,
    YieldBoxApproveAllMsg,
    MarketPermitActionMsg,
    MarketBorrowMsg,
    RemoteTransferMsg,
    MarketRemoveCollateralMsg,
    MarketLeverageDownMsg
} from "contracts/ITOFTv2.sol";
import {ComposeMsgData, PrepareLzCallData, PrepareLzCallReturn} from "contracts/extensions/CommonData.sol";

// Tapioca

/*
__/\\\\\\\\\\\\\\\_____/\\\\\\\\\_____/\\\\\\\\\\\\\____/\\\\\\\\\\\_______/\\\\\_____________/\\\\\\\\\_____/\\\\\\\\\____        
 _\///////\\\/////____/\\\\\\\\\\\\\__\/\\\/////////\\\_\/////\\\///______/\\\///\\\________/\\\////////____/\\\\\\\\\\\\\__       
  _______\/\\\________/\\\/////////\\\_\/\\\_______\/\\\_____\/\\\_______/\\\/__\///\\\____/\\\/____________/\\\/////////\\\_      
   _______\/\\\_______\/\\\_______\/\\\_\/\\\\\\\\\\\\\/______\/\\\______/\\\______\//\\\__/\\\_____________\/\\\_______\/\\\_     
    _______\/\\\_______\/\\\\\\\\\\\\\\\_\/\\\/////////________\/\\\_____\/\\\_______\/\\\_\/\\\_____________\/\\\\\\\\\\\\\\\_    
     _______\/\\\_______\/\\\/////////\\\_\/\\\_________________\/\\\_____\//\\\______/\\\__\//\\\____________\/\\\/////////\\\_   
      _______\/\\\_______\/\\\_______\/\\\_\/\\\_________________\/\\\______\///\\\__/\\\_____\///\\\__________\/\\\_______\/\\\_  
       _______\/\\\_______\/\\\_______\/\\\_\/\\\______________/\\\\\\\\\\\____\///\\\\\/________\////\\\\\\\\\_\/\\\_______\/\\\_ 
        _______\///________\///________\///__\///______________\///////////_______\/////_____________\/////////__\///________\///__

*/

contract TOFTv2Helper {
    // LZ
    uint16 public constant SEND = 1;

    // LZ packets
    uint16 internal constant PT_REMOTE_TRANSFER = 400; // Use for transferring tokens from the contract from another chain

    uint16 internal constant PT_APPROVALS = 500; // Use for ERC20Permit approvals
    uint16 internal constant PT_YB_APPROVE_ASSET = 501; // Use for YieldBox 'setApprovalForAsset(true)' operation
    uint16 internal constant PT_YB_APPROVE_ALL = 502; // Use for YieldBox 'setApprovalForAll(true)' operation
    uint16 internal constant PT_MARKET_PERMIT = 503; // Use for market.permitLend() operation

    uint16 internal constant PT_MARKET_REMOVE_COLLATERAL = 700; // Use for remove collateral from a market available on another chain
    uint16 internal constant PT_YB_SEND_SGL_BORROW = 701; // Use fror send to YB and/or borrow from a market available on another chain
    uint16 internal constant PT_LEVERAGE_MARKET_DOWN = 702; // Use for leverage sell on a market available on another chain
    uint16 internal constant PT_TAP_EXERCISE = 703; // Use for exercise options on tOB available on another chain
    uint16 internal constant PT_SEND_PARAMS = 704; // Use for perform a normal OFT send but with a custom payload

    error InvalidMsgType(uint16 msgType); // Triggered if the msgType is invalid on an `_lzCompose`.
    error InvalidMsgIndex(uint16 msgIndex, uint16 expectedIndex); // The msgIndex does not follow the sequence of indexes in the `_tOFTv2ComposeMsg`
    error InvalidExtraOptionsIndex(uint16 msgIndex, uint16 expectedIndex); // The option index does not follow the sequence of indexes in the `_tOFTv2ComposeMsg`

    /**
     * @dev Convert an amount from shared decimals into local decimals.
     * @param _amountSD The amount in shared decimals.
     * @param _decimalConversionRate The OFT decimal conversion rate
     * @return amountLD The amount in local decimals.
     */
    function toLD(uint64 _amountSD, uint256 _decimalConversionRate) internal view returns (uint256 amountLD) {
        return _amountSD * _decimalConversionRate;
    }

    /**
     * @dev Convert an amount from local decimals into shared decimals.
     * @param _amountLD The amount in local decimals.
     * @param _decimalConversionRate The OFT decimal conversion rate
     * @return amountSD The amount in shared decimals.
     */
    function toSD(uint256 _amountLD, uint256 _decimalConversionRate) internal view virtual returns (uint64 amountSD) {
        return uint64(_amountLD / _decimalConversionRate);
    }

    /**
     * @dev Helper to prepare an LZ call.
     * @return prepareLzCallReturn_ The result of the `prepareLzCall()` function. See `PrepareLzCallReturn`.
     */
    function prepareLzCall(ITOFTv2 tOFTToken, PrepareLzCallData memory _prepareLzCallData)
        public
        view
        returns (PrepareLzCallReturn memory prepareLzCallReturn_)
    {
        SendParam memory sendParam_;
        bytes memory composeOptions_;
        bytes memory composeMsg_;
        MessagingFee memory msgFee_;
        LZSendParam memory lzSendParam_;
        bytes memory oftMsgOptions_;

        // Prepare args call
        sendParam_ = SendParam({
            dstEid: _prepareLzCallData.dstEid,
            to: _prepareLzCallData.recipient,
            amountToSendLD: _prepareLzCallData.amountToSendLD,
            minAmountToCreditLD: _prepareLzCallData.minAmountToCreditLD
        });

        // If compose call found, we get its compose options and message.
        if (_prepareLzCallData.composeMsgData.data.length > 0) {
            composeOptions_ = OptionsBuilder.addExecutorLzComposeOption(
                OptionsBuilder.newOptions(),
                _prepareLzCallData.composeMsgData.index,
                _prepareLzCallData.composeMsgData.gas,
                _prepareLzCallData.composeMsgData.value
            );

            // Build the composed message. Overwrite `composeOptions_` to be with the enforced options.
            (composeMsg_, composeOptions_) = buildTOFTComposeMsgAndOptions(
                tOFTToken,
                _prepareLzCallData.composeMsgData.data,
                _prepareLzCallData.msgType,
                _prepareLzCallData.composeMsgData.index,
                sendParam_.dstEid,
                composeOptions_,
                _prepareLzCallData.composeMsgData.prevData // Previous tapComposeMsg.
            );
        }

        // Append previous option container if any.
        if (_prepareLzCallData.composeMsgData.prevOptionsData.length > 0) {
            require(
                _prepareLzCallData.composeMsgData.prevOptionsData.length > 0, "_prepareLzCall: invalid prevOptionsData"
            );
            oftMsgOptions_ = _prepareLzCallData.composeMsgData.prevOptionsData;
        } else {
            // Else create a new one.
            oftMsgOptions_ = OptionsBuilder.newOptions();
        }

        // Start by appending the lzReceiveOption if lzReceiveGas or lzReceiveValue is > 0.
        if (_prepareLzCallData.lzReceiveValue > 0 || _prepareLzCallData.lzReceiveGas > 0) {
            oftMsgOptions_ = OptionsBuilder.addExecutorLzReceiveOption(
                oftMsgOptions_, _prepareLzCallData.lzReceiveGas, _prepareLzCallData.lzReceiveValue
            );
        }

        // Finally, append the new compose options if any.
        if (composeOptions_.length > 0) {
            // And append the same value passed to the `composeOptions`.
            oftMsgOptions_ = OptionsBuilder.addExecutorLzComposeOption(
                oftMsgOptions_,
                _prepareLzCallData.composeMsgData.index,
                _prepareLzCallData.composeMsgData.gas,
                _prepareLzCallData.composeMsgData.value
            );
        }

        msgFee_ = tOFTToken.quoteSendPacket(sendParam_, oftMsgOptions_, false, composeMsg_, "");

        lzSendParam_ = LZSendParam({
            sendParam: sendParam_,
            fee: msgFee_,
            extraOptions: oftMsgOptions_,
            refundAddress: _prepareLzCallData.refundAddress
        });

        prepareLzCallReturn_ = PrepareLzCallReturn({
            composeMsg: composeMsg_,
            composeOptions: composeOptions_,
            sendParam: sendParam_,
            msgFee: msgFee_,
            lzSendParam: lzSendParam_,
            oftMsgOptions: oftMsgOptions_
        });
    }

    /// =======================
    /// Builder functions
    /// =======================
    /**
     * @notice Encodes the message for the PT_YB_SEND_SGL_BORROW operation.
     *
     */
    function buildMarketLeverageDownMsg(MarketLeverageDownMsg calldata _marketMsg) public pure returns (bytes memory) {
        return TOFTMsgCoder.buildMarketLeverageDownMsg(_marketMsg);
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
        return TOFTMsgCoder.buildMarketRemoveCollateralMsg(_marketMsg);
    }

    /**
     * @notice Encodes the message for the PT_YB_SEND_SGL_BORROW operation.
     *
     */
    function buildMarketBorrowMsg(MarketBorrowMsg calldata _marketBorrowMsg) public pure returns (bytes memory) {
        return TOFTMsgCoder.buildMarketBorrow(_marketBorrowMsg);
    }

    /// =======================
    /// Compose builder functions
    /// =======================

    /**
     * @dev Internal function to build the message and options.
     *
     * @param _msg The TAP message to be encoded.
     * @param _msgType The message type, TAP custom ones, with `PT_` as a prefix.
     * @param _msgIndex The index of the current TAP compose msg.
     * @param _dstEid The destination endpoint ID.
     * @param _extraOptions Extra options for this message. Used to add extra options or aggregate previous `_tapComposedMsg` options.
     * @param _tapComposedMsg The previous TAP compose messages. Empty if this is the first message.
     *
     * @return message The encoded message.
     * @return options The encoded options.
     */
    function buildTOFTComposeMsgAndOptions(
        ITOFTv2 _tOFTv2,
        bytes memory _msg,
        uint16 _msgType,
        uint16 _msgIndex,
        uint32 _dstEid,
        bytes memory _extraOptions,
        bytes memory _tapComposedMsg
    ) public view returns (bytes memory message, bytes memory options) {
        _sanitizeMsgType(_msgType);
        _sanitizeMsgIndex(_msgIndex, _tapComposedMsg);

        message = TOFTMsgCoder.encodeTOFTComposeMsg(_msg, _msgType, _msgIndex, _tapComposedMsg);

        // TODO fix
        // _sanitizeExtraOptionsIndex(_msgIndex, _extraOptions);
        // @dev Combine the callers _extraOptions with the enforced options via the OAppOptionsType3.

        options = _tOFTv2.combineOptions(_dstEid, _msgType, _extraOptions);
    }

    // TODO remove sanitization? If `_sendPacket()` is internal, then the msgType is what we expect it to be.
    /**
     * @dev Sanitizes the message type to match one of the Tapioca supported ones.
     * @param _msgType The message type, custom ones with `PT_` as a prefix.
     */
    function _sanitizeMsgType(uint16 _msgType) internal pure {
        if (
            // LZ
            _msgType == SEND
            // Tapioca msg types
            || _msgType == PT_REMOTE_TRANSFER || _msgType == PT_APPROVALS || _msgType == PT_YB_APPROVE_ASSET
                || _msgType == PT_YB_APPROVE_ALL || _msgType == PT_MARKET_PERMIT || _msgType == PT_MARKET_REMOVE_COLLATERAL
                || _msgType == PT_YB_SEND_SGL_BORROW || _msgType == PT_LEVERAGE_MARKET_DOWN || _msgType == PT_TAP_EXERCISE
                || _msgType == PT_SEND_PARAMS
        ) {
            return;
        }

        revert InvalidMsgType(_msgType);
    }

    /**
     * @dev Sanitizes the msgIndex to match the sequence of indexes in the `_tOFTComposeMsg`.
     *
     * @param _msgIndex The current message index.
     * @param _tOFTComposeMsg The previous TAP compose messages. Empty if this is the first message.
     */
    function _sanitizeMsgIndex(uint16 _msgIndex, bytes memory _tOFTComposeMsg) internal pure {
        // If the msgIndex is 0 and there's no composeMsg, then it's the first message.
        if (_tOFTComposeMsg.length == 0 && _msgIndex == 0) {
            return;
        }

        bytes memory nextMsg_ = _tOFTComposeMsg;
        uint16 lastIndex_;
        while (nextMsg_.length > 0) {
            lastIndex_ = TOFTMsgCoder.decodeIndexOfTOFTComposeMsg(nextMsg_);
            nextMsg_ = TOFTMsgCoder.decodeNextMsgOfTOFTCompose(nextMsg_);
        }

        // If there's a composeMsg, then the msgIndex must be greater than 0, and an increment of the last msgIndex.
        uint16 expectedMsgIndex_ = lastIndex_ + 1;
        if (_tOFTComposeMsg.length > 0) {
            if (_msgIndex == expectedMsgIndex_) {
                return;
            }
        }

        revert InvalidMsgIndex(_msgIndex, expectedMsgIndex_);
    }

    /// =======================
    /// Builder functions
    /// =======================

    /**
     * @notice Encodes the message for the `remoteTransfer` operation.
     * @param _remoteTransferMsg The owner + LZ send param to pass on the remote chain. (B->A)
     */
    function buildRemoteTransferMsg(RemoteTransferMsg memory _remoteTransferMsg) public pure returns (bytes memory) {
        return TOFTMsgCoder.buildRemoteTransferMsg(_remoteTransferMsg);
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
        msg_ = abi.encodePacked(msg_, TOFTMsgCoder.buildMarketPermitApprovalMsg(_marketPermitActionMsg));
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
        msg_ = abi.encodePacked(msg_, TOFTMsgCoder.buildYieldBoxApproveAllMsg(_yieldBoxApprovalAllMsg));
    }

    /**
     * @notice Encode the message for the _erc20PermitApprovalReceiver(),
     *   _yieldBoxRevokeAssetReceiver() & _yieldBoxApproveAssetReceiver operations.
     * @param _erc20PermitApprovalMsg The ERC20 permit approval messages.
     */
    function buildPermitApprovalMsg(ERC20PermitApprovalMsg[] memory _erc20PermitApprovalMsg)
        public
        pure
        returns (bytes memory msg_)
    {
        uint256 approvalsLength = _erc20PermitApprovalMsg.length;
        for (uint256 i; i < approvalsLength;) {
            msg_ = abi.encodePacked(msg_, TOFTMsgCoder.buildERC20PermitApprovalMsg(_erc20PermitApprovalMsg[i]));
            unchecked {
                ++i;
            }
        }
    }
}
