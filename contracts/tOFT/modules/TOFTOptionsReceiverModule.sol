// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {
    MessagingReceipt, OFTReceipt, SendParam
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {IOAppMsgInspector} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppMsgInspector.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";

// External
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

// Tapioca
import {
    ITapiocaOptionBroker, IExerciseOptionsData
} from "tapioca-periph/interfaces/tap-token/ITapiocaOptionBroker.sol";
import {TOFTInitStruct, ExerciseOptionsMsg, LZSendParam} from "tapioca-periph/interfaces/oft/ITOFT.sol";
import {TOFTMsgCodec} from "contracts/tOFT/libraries/TOFTMsgCodec.sol";
import {BaseTOFT} from "contracts/tOFT/BaseTOFT.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

/**
 * @title TOFTOptionsReceiverModule
 * @author TapiocaDAO
 * @notice TOFT Options module
 */
contract TOFTOptionsReceiverModule is BaseTOFT {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    error TOFTOptionsReceiverModule_NotAuthorized(address invalidAddress);

    event ExerciseOptionsReceived(
        address indexed user, address indexed target, uint256 indexed oTapTokenId, uint256 paymentTokenAmount
    );

    constructor(TOFTInitStruct memory _data) BaseTOFT(_data) {}

    /**
     * @notice Exercise tOB option
     * @param _data The call data containing info about the operation.
     *      - optionsData::address: TapiocaOptionsBroker exercise params.
     *      - lzSendParams::struct: LZ v2 send to source params.
     *      - composeMsg::bytes: Further compose data.
     */
    function exerciseOptionsReceiver(address srcChainSender, bytes memory _data) public payable {
        // Decode received message.
        ExerciseOptionsMsg memory msg_ = TOFTMsgCodec.decodeExerciseOptionsMsg(_data);

        _checkWhitelistStatus(msg_.optionsData.target);
        _checkWhitelistStatus(OFTMsgCodec.bytes32ToAddress(msg_.lzSendParams.sendParam.to));

        {
            // _data declared for visibility.
            IExerciseOptionsData memory _options = msg_.optionsData;
            _options.tapAmount = _toLD(_options.tapAmount.toUint64());
            _options.paymentTokenAmount = _toLD(_options.paymentTokenAmount.toUint64());

            // @dev retrieve paymentToken amount
            _internalTransferWithAllowance(_options.from, srcChainSender, _options.paymentTokenAmount);

            /// @dev call exerciseOption() with address(this) as the payment token
            _approve(address(this), _options.target, 0);
            _approve(address(this), _options.target, _options.paymentTokenAmount);
            uint256 bBefore = balanceOf(address(this));
            ITapiocaOptionBroker(_options.target).exerciseOption(
                _options.oTAPTokenID,
                address(this), //payment token
                _options.tapAmount
            );
            _approve(address(this), _options.target, 0);
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
            IExerciseOptionsData memory _options = msg_.optionsData;
            SendParam memory _send = msg_.lzSendParams.sendParam;

            address tapOft = ITapiocaOptionBroker(_options.target).tapOFT();
            if (msg_.withdrawOnOtherChain) {
                /// @dev determine the right amount to send back to source
                uint256 amountToSend = _send.amountLD > _options.tapAmount ? _options.tapAmount : _send.amountLD;
                if (_send.minAmountLD > amountToSend) {
                    _send.minAmountLD = amountToSend;
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
                revert TOFTOptionsReceiverModule_NotAuthorized(_addr);
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
        (uint256 amountDebitedLD, uint256 amountToCreditLD) =
            _debit(_lzSendParam.sendParam.amountLD, _lzSendParam.sendParam.minAmountLD, _lzSendParam.sendParam.dstEid);

        /// @dev Builds the options and OFT message to quote in the endpoint.
        (bytes memory message, bytes memory options) = _buildOFTMsgAndOptionsMemory(
            _lzSendParam.sendParam, _lzSendParam.extraOptions, _composeMsg, amountToCreditLD, _srcChainSender
        );

        /// @dev Sends the message to the LayerZero endpoint and returns the LayerZero msg receipt.
        msgReceipt =
            _lzSend(_lzSendParam.sendParam.dstEid, message, options, _lzSendParam.fee, _lzSendParam.refundAddress);
        /// @dev Formulate the OFT receipt.
        oftReceipt = OFTReceipt(amountDebitedLD, amountToCreditLD);

        emit OFTSent(msgReceipt.guid, _lzSendParam.sendParam.dstEid, msg.sender, amountDebitedLD);
    }
    /**
     * @dev For details about this function, check `BaseTapiocaOmnichainEngine._buildOFTMsgAndOptions()`.
     * @dev !!!! IMPORTANT !!!! The differences are:
     *      - memory instead of calldata for parameters.
     *      - `_msgSender` is used instead of using context `msg.sender`, to preserve context of the OFT call and use `msg.sender` of the source chain.
     *      - Does NOT combine options, make sure to pass valid options to cover gas costs/value transfers.
     */

    function _buildOFTMsgAndOptionsMemory(
        SendParam memory _sendParam,
        bytes memory _extraOptions,
        bytes memory _composeMsg,
        uint256 _amountToCreditLD,
        address _msgSender
    ) private view returns (bytes memory message, bytes memory options) {
        bool hasCompose = _composeMsg.length > 0;

        message = hasCompose
            ? abi.encodePacked(
                _sendParam.to, _toSD(_amountToCreditLD), OFTMsgCodec.addressToBytes32(_msgSender), _composeMsg
            )
            : abi.encodePacked(_sendParam.to, _toSD(_amountToCreditLD));
        options = _extraOptions;

        if (msgInspector != address(0)) {
            IOAppMsgInspector(msgInspector).inspect(message, options);
        }
    }

    /**
     * @dev Performs a transfer with an allowance check and consumption against the xChain msg sender.
     * @dev Can only transfer to this address.
     *
     * @param _owner The account to transfer from.
     * @param srcChainSender The address of the sender on the source chain.
     * @param _amount The amount to transfer
     */
    function _internalTransferWithAllowance(address _owner, address srcChainSender, uint256 _amount) internal {
        if (_owner != srcChainSender) {
            _spendAllowance(_owner, srcChainSender, _amount);
        }

        _transfer(_owner, address(this), _amount);
    }
}
