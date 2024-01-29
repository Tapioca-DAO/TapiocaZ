// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {
    MessagingReceipt, OFTReceipt, SendParam
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {IOAppMsgInspector} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppMsgInspector.sol";
import {IOAppComposer} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppComposer.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import {Origin} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";

// External
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Tapioca
import {
    ITOFTv2,
    TOFTInitStruct,
    ERC20PermitApprovalMsg,
    ERC20PermitApprovalMsg,
    LZSendParam,
    YieldBoxApproveAllMsg,
    MarketPermitActionMsg,
    RemoteTransferMsg,
    MarketRemoveCollateralMsg,
    SendParamsMsg,
    YieldBoxApproveAssetMsg
} from "contracts/ITOFTv2.sol";
import {TOFTv2MarketReceiverModule} from "contracts/modules/TOFTv2MarketReceiverModule.sol";
import {TOFTv2OptionsReceiverModule} from "contracts/modules/TOFTv2OptionsReceiverModule.sol";
import {TOFTv2GenericReceiverModule} from "contracts/modules/TOFTv2GenericReceiverModule.sol";
import {TOFTMsgCoder} from "contracts/libraries/TOFTMsgCoder.sol";
import {TOFTv2Sender} from "contracts/modules/TOFTv2Sender.sol";
import {BaseTOFTv2} from "contracts/BaseTOFTv2.sol";

import "forge-std/console.sol";

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

contract TOFTv2Receiver is BaseTOFTv2, IOAppComposer {
    using OFTMsgCodec for bytes;
    using OFTMsgCodec for bytes32;
    using SafeERC20 for IERC20;

    /**
     *  @dev Triggered if the address of the composer doesn't match current contract in `lzCompose`.
     * Compose caller and receiver are the same address, which is this.
     */
    error InvalidComposer(address composer);
    error InvalidCaller(address caller); // Should be the endpoint address
    error InsufficientAllowance(address owner, uint256 amount); // See `this.__internalTransferWithAllowance()`
    error InvalidApprovalTarget(address target); // Should be a whitelisted address available on the Cluster contract
    error TransferFailed();

    event RemoteTransferReceived(address indexed owner, uint256 indexed dstEid, address indexed to, uint256 amount);

    /// @dev Compose received.
    event ComposeReceived(uint16 indexed msgType, bytes32 indexed guid, bytes composeMsg);

    constructor(TOFTInitStruct memory _data) BaseTOFTv2(_data) {}

    /**
     * @dev !!! FIRST ENTRYPOINT, COMPOSE MSG ARE TO BE BUILT HERE  !!!
     *
     * @dev Slightly modified version of the OFT _lzReceive() operation.
     * The composed message is sent to `address(this)` instead of `toAddress`.
     * @dev Internal function to handle the receive on the LayerZero endpoint.
     * @dev Caller is verified on the public function. See `OAppReceiver.lzReceive()`.
     *
     * @param _origin The origin information.
     *  - srcEid: The source chain endpoint ID.
     *  - sender: The sender address from the src chain.
     *  - nonce: The nonce of the LayerZero message.
     * @param _guid The unique identifier for the received LayerZero message.
     * @param _message The encoded message.
     * _executor The address of the executor.
     * _extraData Additional data.
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address, /*_executor*/ // @dev unused in the default implementation.
        bytes calldata /*_extraData*/ // @dev unused in the default implementation.
    ) internal virtual override {
        // @dev The src sending chain doesn't know the address length on this chain (potentially non-evm)
        // Thus everything is bytes32() encoded in flight.
        address toAddress = _message.sendTo().bytes32ToAddress();
        // @dev Convert the amount to credit into local decimals.
        uint256 amountToCreditLD = _toLD(_message.amountSD());
        // @dev Credit the amount to the recipient and return the ACTUAL amount the recipient received in local decimals
        uint256 amountReceivedLD = _credit(toAddress, amountToCreditLD, _origin.srcEid);

        if (_message.isComposed()) {
            // @dev Stores the lzCompose payload that will be executed in a separate tx.
            // Standardizes functionality for executing arbitrary contract invocation on some non-evm chains.
            // @dev The off-chain executor will listen and process the msg based on the src-chain-callers compose options passed.
            // @dev The index is used when a OApp needs to compose multiple msgs on lzReceive.
            // For default OFT implementation there is only 1 compose msg per lzReceive, thus its always 0.
            endpoint.sendCompose(
                address(this), // Updated from default `toAddress`
                _guid,
                0, /* the index of the composed message*/
                _message.composeMsg()
            );
        }

        emit OFTReceived(_guid, _origin.srcEid, toAddress, amountReceivedLD);
    }

    /**
     * @dev !!! SECOND ENTRYPOINT, CALLER NEEDS TO BE VERIFIED !!!
     *
     * @notice Composes a LayerZero message from an OApp.
     * @dev The message comes in form:
     *      - [composeSender::address][oftComposeMsg::bytes]
     *                                          |
     *                                          |
     *                        [msgType::uint16, composeMsg::bytes]
     * @dev The composeSender is the user that initiated the `sendPacket()` call on the srcChain.
     *
     * @param _from The address initiating the composition, typically the OApp where the lzReceive was called.
     * @param _guid The unique identifier for the corresponding LayerZero src/dst tx.
     * @param _message The composed message payload in bytes. NOT necessarily the same payload passed via lzReceive.
     */
    function lzCompose(
        address _from,
        bytes32 _guid,
        bytes calldata _message,
        address, // _executor The address of the executor for the composed message.
        bytes calldata // _extraData Additional arbitrary data in bytes passed by the entity who executes the lzCompose.
    ) external payable override {
        // Validate the from and the caller.
        if (_from != address(this)) {
            revert InvalidComposer(_from);
        }
        if (msg.sender != address(endpoint)) {
            revert InvalidCaller(msg.sender);
        }

        // Decode LZ compose message.
        (address srcChainSender_, bytes memory oftComposeMsg_) = TOFTMsgCoder.decodeLzComposeMsg(_message);

        // Decode OFT compose message.
        (uint16 msgType_,, uint16 msgIndex_, bytes memory tOFTComposeMsg_, bytes memory nextMsg_) =
            TOFTMsgCoder.decodeTOFTComposeMsg(oftComposeMsg_);

        if (msgType_ == PT_REMOTE_TRANSFER) {
            _remoteTransferReceiver(srcChainSender_, tOFTComposeMsg_);
        } else if (msgType_ == PT_APPROVALS) {
            _erc20PermitApprovalReceiver(tOFTComposeMsg_);
        } else if (msgType_ == PT_YB_APPROVE_ALL) {
            _yieldBoxPermitAllReceiver(tOFTComposeMsg_);
        } else if (msgType_ == PT_YB_APPROVE_ASSET) {
            _yieldBoxPermitAssetReceiver(tOFTComposeMsg_);
        } else if (msgType_ == PT_MARKET_PERMIT) {
            _marketPermitReceiver(tOFTComposeMsg_);
        } else if (msgType_ == PT_YB_SEND_SGL_BORROW) {
            _executeModule(
                uint8(ITOFTv2.Module.TOFTv2MarketReceiver),
                abi.encodeWithSelector(TOFTv2MarketReceiverModule.marketBorrowReceiver.selector, tOFTComposeMsg_),
                false
            );
        } else if (msgType_ == PT_MARKET_REMOVE_COLLATERAL) {
            _executeModule(
                uint8(ITOFTv2.Module.TOFTv2MarketReceiver),
                abi.encodeWithSelector(
                    TOFTv2MarketReceiverModule.marketRemoveCollateralReceiver.selector, tOFTComposeMsg_
                ),
                false
            );
        } else if (msgType_ == PT_LEVERAGE_MARKET_DOWN) {
            _executeModule(
                uint8(ITOFTv2.Module.TOFTv2MarketReceiver),
                abi.encodeWithSelector(TOFTv2MarketReceiverModule.marketLeverageDownReceiver.selector, tOFTComposeMsg_),
                false
            );
        } else if (msgType_ == PT_TAP_EXERCISE) {
            _executeModule(
                uint8(ITOFTv2.Module.TOFTv2OptionsReceiver),
                abi.encodeWithSelector(
                    TOFTv2OptionsReceiverModule.exerciseOptionsReceiver.selector, srcChainSender_, tOFTComposeMsg_
                ),
                false
            );
        } else if (msgType_ == PT_SEND_PARAMS) {
            _executeModule(
                uint8(ITOFTv2.Module.TOFTv2GenericReceiver),
                abi.encodeWithSelector(
                    TOFTv2GenericReceiverModule.receiveWithParamsReceiver.selector, srcChainSender_, tOFTComposeMsg_
                ),
                false
            );
        } else {
            revert InvalidMsgType(msgType_);
        }

        emit ComposeReceived(msgType_, _guid, _message);

        if (nextMsg_.length > 0) {
            endpoint.sendCompose(
                address(this),
                _guid,
                msgIndex_ + 1, // Increment the index
                abi.encodePacked(OFTMsgCodec.addressToBytes32(srcChainSender_), nextMsg_) // Re encode the compose msg with the composeSender
            );
        }
    }

    // ********************* //
    // ***** RECEIVERS ***** //
    // ********************* //
    /**
     * // TODO Check if it's safe to send composed messages too.
     * // TODO Write test for composed messages call. A->B->A-B/C?
     * @dev Transfers tokens AND composed messages from this contract to the recipient on the chain A. Flow of calls is: A->B->A.
     * @dev The user needs to have approved the TapOFTv2 contract to spend the TAP.
     *
     * @param _srcChainSender The address of the sender on the source chain.
     * @param _data The call data containing info about the transfer (LZSendParam).
     */
    function _remoteTransferReceiver(address _srcChainSender, bytes memory _data) internal virtual {
        RemoteTransferMsg memory remoteTransferMsg_ = TOFTMsgCoder.decodeRemoteTransferMsg(_data);

        /// @dev xChain owner needs to have approved dst srcChain `sendPacket()` msg.sender in a previous composedMsg. Or be the same address.
        _internalTransferWithAllowance(
            remoteTransferMsg_.owner, _srcChainSender, remoteTransferMsg_.lzSendParam.sendParam.amountLD
        );

        // Make the internal transfer, burn the tokens from this contract and send them to the recipient on the other chain.
        _internalRemoteTransferSendPacket(
            remoteTransferMsg_.owner, remoteTransferMsg_.lzSendParam, remoteTransferMsg_.composeMsg
        );

        emit RemoteTransferReceived(
            remoteTransferMsg_.owner,
            remoteTransferMsg_.lzSendParam.sendParam.dstEid,
            OFTMsgCodec.bytes32ToAddress(remoteTransferMsg_.lzSendParam.sendParam.to),
            remoteTransferMsg_.lzSendParam.sendParam.amountLD
        );
    }

    /**
     * // TODO review this function.
     *
     * @dev Slightly modified version of the OFT _sendPacket() operation. To accommodate the `srcChainSender` parameter and potential dust.
     * @dev !!! IMPORTANT !!! made ONLY for the `_remoteTransferReceiver()` operation.
     */
    function _internalRemoteTransferSendPacket(
        address _srcChainSender,
        LZSendParam memory _lzSendParam,
        bytes memory _composeMsg
    ) internal returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) {
        // Burn tokens from this contract
        (uint256 amountDebitedLD_, uint256 amountToCreditLD_) =
            _debit(_lzSendParam.sendParam.amountLD, _lzSendParam.sendParam.minAmountLD, _lzSendParam.sendParam.dstEid);

        _lzSendParam.sendParam.amountLD = amountToCreditLD_;
        _lzSendParam.sendParam.minAmountLD = amountToCreditLD_;

        // If the srcChain amount request is bigger than the debited one, overwrite the amount to credit with the amount debited and send the difference back to the user.
        if (_lzSendParam.sendParam.amountLD > amountDebitedLD_) {
            // Overwrite the amount to credit with the amount debited
            _lzSendParam.sendParam.amountLD = amountDebitedLD_;
            _lzSendParam.sendParam.minAmountLD = amountDebitedLD_;
            // Send the difference back to the user
            _transfer(address(this), _srcChainSender, _lzSendParam.sendParam.amountLD - amountDebitedLD_);
        }

        // Builds the options and OFT message to quote in the endpoint.
        (bytes memory message, bytes memory options) = _buildOFTMsgAndOptions(
            _lzSendParam.sendParam, _lzSendParam.extraOptions, _composeMsg, amountToCreditLD_, _srcChainSender, true
        ); // msgSender is the sender of the composed message. We keep context by passing `_srcChainSender`.

        // Sends the message to the LayerZero endpoint and returns the LayerZero msg receipt.
        msgReceipt =
            _lzSend(_lzSendParam.sendParam.dstEid, message, options, _lzSendParam.fee, _lzSendParam.refundAddress);
        // Formulate the OFT receipt.
        oftReceipt = OFTReceipt(amountDebitedLD_, amountToCreditLD_);

        emit OFTSent(msgReceipt.guid, _lzSendParam.sendParam.dstEid, _srcChainSender, amountDebitedLD_);
    }

    /**
     * @notice Approves Market lend/borrow via permit.
     * @param _data The call data containing info about the approval.
     *      - token::address: Address of the YieldBox to approve.
     *      - owner::address: Address of the owner of the tokens.
     *      - spender::address: Address of the spender.
     *      - value::uint256: Amount of tokens to approve.
     *      - deadline::uint256: Deadline for the approval.
     *      - v::uint8: v value of the signature.
     *      - r::bytes32: r value of the signature.
     *      - s::bytes32: s value of the signature.
     */
    function _marketPermitReceiver(bytes memory _data) internal virtual {
        MarketPermitActionMsg memory approval = TOFTMsgCoder.decodeMarketPermitApprovalMsg(_data);

        _sanitizeTarget(approval.target);

        if (approval.permitAsset) {
            toftV2ExtExec.marketPermitAssetApproval(approval);
        } else {
            toftV2ExtExec.marketPermitCollateralApproval(approval);
        }
    }

    /**
     * @notice Approves YieldBox asset via permit.
     * @param _data The call data containing info about the approvals.
     *      - token::address: Address of the YieldBox to approve.
     *      - owner::address: Address of the owner of the tokens.
     *      - spender::address: Address of the spender.
     *      - value::uint256: Amount of tokens to approve.
     *      - deadline::uint256: Deadline for the approval.
     *      - v::uint8: v value of the signature.
     *      - r::bytes32: r value of the signature.
     *      - s::bytes32: s value of the signature.
     */
    function _yieldBoxPermitAssetReceiver(bytes memory _data) internal virtual {
        YieldBoxApproveAssetMsg[] memory approvals = TOFTMsgCoder.decodeArrayOfYieldBoxPermitAssetMsg(_data);

        uint256 approvalsLength = approvals.length;
        for (uint256 i = 0; i < approvalsLength;) {
            _sanitizeTarget(approvals[i].target);
            unchecked {
                ++i;
            }
        }

        toftV2ExtExec.yieldBoxPermitApproveAsset(approvals);
    }

    /**
     * @notice Approves all assets on YieldBox.
     * @param _data The call data containing info about the approval.
     *      - target::address: Address of the YieldBox contract.
     *      - owner::address: Address of the owner of the tokens.
     *      - spender::address: Address of the spender.
     *      - deadline::uint256: Deadline for the approval.
     *      - v::uint8: v value of the signature.
     *      - r::bytes32: r value of the signature.
     *      - s::bytes32: s value of the signature.
     */
    function _yieldBoxPermitAllReceiver(bytes memory _data) internal virtual {
        YieldBoxApproveAllMsg memory approval = TOFTMsgCoder.decodeYieldBoxApproveAllMsg(_data);

        _sanitizeTarget(approval.target);

        if (approval.permit) {
            toftV2ExtExec.yieldBoxPermitApproveAll(approval);
        } else {
            toftV2ExtExec.yieldBoxPermitRevokeAll(approval);
        }
    }

    /**
     * @notice Approves tokens via permit.
     * @param _data The call data containing info about the approvals.
     *      - token::address: Address of the token to approve.
     *      - owner::address: Address of the owner of the tokens.
     *      - spender::address: Address of the spender.
     *      - value::uint256: Amount of tokens to approve.
     *      - deadline::uint256: Deadline for the approval.
     *      - v::uint8: v value of the signature.
     *      - r::bytes32: r value of the signature.
     *      - s::bytes32: s value of the signature.
     */
    function _erc20PermitApprovalReceiver(bytes memory _data) internal virtual {
        ERC20PermitApprovalMsg[] memory approvals = TOFTMsgCoder.decodeArrayOfERC20PermitApprovalMsg(_data);

        toftV2ExtExec.erc20PermitApproval(approvals);
    }

    function _sanitizeTarget(address target) private view {
        if (!cluster.isWhitelisted(0, target)) {
            revert InvalidApprovalTarget(target);
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
