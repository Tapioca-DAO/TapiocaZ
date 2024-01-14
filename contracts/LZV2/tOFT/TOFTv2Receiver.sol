// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {IOAppComposer} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppComposer.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import {Origin} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";

// External
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Tapioca
import {TOFTv2MsgCoder} from "./libraries/TOFTv2MsgCoder.sol";
import {TOFTv2Sender} from "./TOFTv2Sender.sol";
import {TOFTInitStruct} from "./ITOFTv2.sol";
import {BaseTOFTv2} from "./BaseTOFTv2.sol";

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

    /**
     *  @dev Triggered if the address of the composer doesn't match current contract in `lzCompose`.
     * Compose caller and receiver are the same address, which is this.
     */
    error InvalidComposer(address composer);
    error InvalidCaller(address caller); // Should be the endpoint address
    error InsufficientAllowance(address owner, uint256 amount); // See `this.__internalTransferWithAllowance()`
    // See `this._claimTwpTapRewardsReceiver()`. Triggered if the length of the claimed rewards are not equal to the length of the lzSendParam array.
    error InvalidSendParamLength(uint256 expectedLength, uint256 actualLength);

    /// @dev Compose received.
    event ComposeReceived(
        uint16 indexed msgType,
        bytes32 indexed guid,
        bytes composeMsg
    );

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
        address /*_executor*/, // @dev unused in the default implementation.
        bytes calldata /*_extraData*/ // @dev unused in the default implementation.
    ) internal virtual override {
        // @dev The src sending chain doesn't know the address length on this chain (potentially non-evm)
        // Thus everything is bytes32() encoded in flight.
        address toAddress = _message.sendTo().bytes32ToAddress();
        // @dev Convert the amount to credit into local decimals.
        uint256 amountToCreditLD = _toLD(_message.amountSD());
        // @dev Credit the amount to the recipient and return the ACTUAL amount the recipient received in local decimals
        uint256 amountReceivedLD = _credit(
            toAddress,
            amountToCreditLD,
            _origin.srcEid
        );

        if (_message.isComposed()) {
            // @dev Stores the lzCompose payload that will be executed in a separate tx.
            // Standardizes functionality for executing arbitrary contract invocation on some non-evm chains.
            // @dev The off-chain executor will listen and process the msg based on the src-chain-callers compose options passed.
            // @dev The index is used when a OApp needs to compose multiple msgs on lzReceive.
            // For default OFT implementation there is only 1 compose msg per lzReceive, thus its always 0.
            endpoint.sendCompose(
                address(this), // Updated from default `toAddress`
                _guid,
                0 /* the index of the composed message*/,
                _message.composeMsg()
            );
        }

        emit OFTReceived(_guid, toAddress, amountToCreditLD, amountReceivedLD);
    }

    // TODO - SANITIZE MSG TYPE
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
        (address composeSender_, bytes memory oftComposeMsg_) = TOFTv2MsgCoder
            .decodeLzComposeMsg(_message);

        // Decode OFT compose message.
        (
            uint16 msgType_,
            ,
            uint16 msgIndex_,
            bytes memory tOFTComposeMsg_,
            bytes memory nextMsg_
        ) = TOFTv2MsgCoder.decodeTOFTComposeMsg(oftComposeMsg_);

        //TODO: implement custom packets
        // if (msgType_ == PT_APPROVALS) {
        //     _erc20PermitApprovalReceiver(tapComposeMsg_);
        // } else if (msgType_ == PT_NFT_APPROVALS) {
        //     _erc721PermitApprovalReceiver(tapComposeMsg_);
        // } else if (msgType_ == PT_LOCK_TWTAP) {
        //     _lockTwTapPositionReceiver(tapComposeMsg_);
        // } else if (msgType_ == PT_UNLOCK_TWTAP) {
        //     _unlockTwTapPositionReceiver(tapComposeMsg_);
        // } else if (msgType_ == PT_CLAIM_REWARDS) {
        //     _claimTwpTapRewardsReceiver(tapComposeMsg_);
        // } else if (msgType_ == PT_REMOTE_TRANSFER) {
        //     _remoteTransferReceiver(tapComposeMsg_);
        // } else {
        //     revert InvalidMsgType(msgType_);
        // }

        emit ComposeReceived(msgType_, _guid, _message);

        if (nextMsg_.length > 0) {
            endpoint.sendCompose(
                address(this),
                _guid,
                msgIndex_ + 1, // Increment the index
                abi.encodePacked(
                    OFTMsgCodec.addressToBytes32(composeSender_),
                    nextMsg_
                ) // Re encode the compose msg with the composeSender
            );
        }
    }
}
