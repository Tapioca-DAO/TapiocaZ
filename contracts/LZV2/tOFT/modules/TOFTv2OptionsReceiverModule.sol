// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {
    MessagingReceipt, OFTReceipt, SendParam
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

// External
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol";

// Tapioca
import {
    ITapiocaOptionsBroker,
    ITapiocaOptionsBrokerCrossChain
} from "tapioca-periph/contracts/interfaces/ITapiocaOptionsBroker.sol";
import {TOFTInitStruct, ExerciseOptionsMsg, LZSendParam} from "contracts/ITOFTv2.sol";
import {TOFTMsgCoder} from "contracts/libraries/TOFTMsgCoder.sol";
import {BaseTOFTv2} from "contracts/BaseTOFTv2.sol";

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

//TODO: perform ld2sd and sd2ld on uint256

/**
 * @title TOFTv2OptionsReceiverModule
 * @author TapiocaDAO
 * @notice TOFTv2 Options module
 */
contract TOFTv2OptionsReceiverModule is BaseTOFTv2 {
    using SafeERC20 for IERC20;

    error TOFTv2OptionsReceiverModule_NotAuthorized(address invalidAddress);

    event ExerciseOptionsReceived(
        address indexed user, address indexed target, uint256 indexed oTapTokenId, uint256 paymentTokenAmount
    );

    constructor(TOFTInitStruct memory _data) BaseTOFTv2(_data) {}

    /**
     * @notice Exercise tOB option
     * @param _data The call data containing info about the operation.
     *      - optionsData::address: TapiocaOptionsBroker exercise params.
     *      - lzSendParams::struct: LZ v2 send to source params.
     *      - composeMsg::bytes: Further compose data.
     */
    function exerciseOptionsReceiver(bytes memory _data) public payable {
        // Decode received message.
        ExerciseOptionsMsg memory msg_ = TOFTMsgCoder.decodeExerciseOptionsMsg(_data);

        _checkWhitelistStatus(msg_.optionsData.target);
        _checkWhitelistStatus(LzLib.bytes32ToAddress(msg_.lzSendParams.sendParam.to));

        {
            // _data declared for visibility.
            ITapiocaOptionsBrokerCrossChain.IExerciseOptionsData memory _options = msg_.optionsData;
            _options.tapAmount = _toLD(uint64(_options.tapAmount));
            _options.paymentTokenAmount = _toLD(uint64(_options.paymentTokenAmount));

            /// @dev call exerciseOption() with address(this) as the payment token
            uint256 bBefore = balanceOf(address(this));
            ITapiocaOptionsBroker(_options.target).exerciseOption(
                _options.oTAPTokenID,
                address(this), //payment token
                _options.tapAmount
            );
            uint256 bAfter = balanceOf(address(this));

            // Refund if less was used.
            if (bBefore > bAfter) {
                uint256 diff = bBefore - bAfter;
                if (diff < _options.paymentTokenAmount) {
                    IERC20(address(this)).safeTransfer(_options.from, _options.paymentTokenAmount - diff);
                }
            }
        }

        {
            // _data declared for visibility.
            ITapiocaOptionsBrokerCrossChain.IExerciseOptionsData memory _options = msg_.optionsData;
            SendParam memory _send = msg_.lzSendParams.sendParam;

            address tapOft = ITapiocaOptionsBroker(_options.target).tapOFT();
            if (msg_.withdrawOnOtherChain) {
                /// @dev determine the right amount to send back to source
                uint256 amountToSend =
                    _send.amountToSendLD > _options.tapAmount ? _options.tapAmount : _send.amountToSendLD;
                if (_send.minAmountToCreditLD > amountToSend) {
                    _send.minAmountToCreditLD = amountToSend;
                }

                // Sends to source and preserve source `msg.sender` (`from` in this case).
                _sendPacket(msg_.lzSendParams, msg_.composeMsg, _options.from);

                // Refund extra amounts
                if (_options.tapAmount - amountToSend > 0) {
                    IERC20(tapOft).safeTransfer(_options.from, _options.tapAmount - amountToSend);
                }
            } else {
                //send on this chain
                IERC20(tapOft).safeTransfer(_options.from, _options.tapAmount);
            }
        }
    }

    function _checkWhitelistStatus(address _addr) private view {
        if (_addr != address(0)) {
            if (!cluster.isWhitelisted(0, _addr)) {
                revert TOFTv2OptionsReceiverModule_NotAuthorized(_addr);
            }
        }
    }

    function _sendPacket(LZSendParam memory _lzSendParam, bytes memory _composeMsg, address _srcChainSender)
        private
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt)
    {
        /// @dev Applies the token transfers regarding this send() operation.
        // - amountDebitedLD is the amount in local decimals that was ACTUALLY debited from the sender.
        // - amountToCreditLD is the amount in local decimals that will be credited to the recipient on the remote OFT instance.
        (uint256 amountDebitedLD, uint256 amountToCreditLD) = _debit(
            _lzSendParam.sendParam.amountToSendLD,
            _lzSendParam.sendParam.minAmountToCreditLD,
            _lzSendParam.sendParam.dstEid
        );

        /// @dev Builds the options and OFT message to quote in the endpoint.
        (bytes memory message, bytes memory options) = _buildOFTMsgAndOptions(
            _lzSendParam.sendParam, _lzSendParam.extraOptions, _composeMsg, amountToCreditLD, _srcChainSender, true
        );

        /// @dev Sends the message to the LayerZero endpoint and returns the LayerZero msg receipt.
        msgReceipt =
            _lzSend(_lzSendParam.sendParam.dstEid, message, options, _lzSendParam.fee, _lzSendParam.refundAddress);
        /// @dev Formulate the OFT receipt.
        oftReceipt = OFTReceipt(amountDebitedLD, amountToCreditLD);

        emit OFTSent(msgReceipt.guid, msg.sender, amountDebitedLD, amountToCreditLD, _composeMsg);
    }
}
