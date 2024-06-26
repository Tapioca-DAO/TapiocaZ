// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

//LZ
import {
    MessagingReceipt,
    OFTReceipt,
    SendParam,
    MessagingFee
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {IMessagingChannel} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessagingChannel.sol";
import {OAppReceiver} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppReceiver.sol";
import {Origin} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import {OFTCore} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";

// External
import {ERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

// Tapioca
import {
    ITOFT,
    TOFTInitStruct,
    TOFTModulesInitStruct,
    LZSendParam,
    ERC20PermitStruct,
    IToftVault
} from "tapioca-periph/interfaces/oft/ITOFT.sol";
import {BaseTapiocaOmnichainEngine} from "tapioca-periph/tapiocaOmnichainEngine/BaseTapiocaOmnichainEngine.sol";
import {TapiocaOmnichainSender} from "tapioca-periph/tapiocaOmnichainEngine/TapiocaOmnichainSender.sol";
import {TOFTReceiver} from "./modules/TOFTReceiver.sol";
import {TOFTSender} from "./modules/TOFTSender.sol";
import {BaseTOFT} from "./BaseTOFT.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

/**
 * @title TOFT
 * @author TapiocaDAO
 * @notice Tapioca OFT wrapper contract
 * @dev It can be wrapped and unwrapped only on host chain
 */
contract TOFT is BaseTOFT, ReentrancyGuard, ERC20Permit {
    error TOFT_OnlyHostChain();
    error TOFT_NotNative();
    error TOFT_Failed();

    modifier onlyHostChain() {
        if (_getChainId() != hostEid) revert TOFT_OnlyHostChain();
        _;
    }

    constructor(TOFTInitStruct memory _tOFTData, TOFTModulesInitStruct memory _modulesData)
        BaseTOFT(_tOFTData)
        ERC20Permit(_tOFTData.name)
    {
        // Set TOFT execution modules
        if (_modulesData.tOFTSenderModule == address(0)) revert TOFT_NotValid();
        if (_modulesData.tOFTReceiverModule == address(0)) {
            revert TOFT_NotValid();
        }
        if (_modulesData.marketReceiverModule == address(0)) {
            revert TOFT_NotValid();
        }
        if (_modulesData.optionsReceiverModule == address(0)) {
            revert TOFT_NotValid();
        }
        if (_modulesData.genericReceiverModule == address(0)) {
            revert TOFT_NotValid();
        }

        _setModule(uint8(ITOFT.Module.TOFTSender), _modulesData.tOFTSenderModule);
        _setModule(uint8(ITOFT.Module.TOFTReceiver), _modulesData.tOFTReceiverModule);
        _setModule(uint8(ITOFT.Module.TOFTMarketReceiver), _modulesData.marketReceiverModule);
        _setModule(uint8(ITOFT.Module.TOFTOptionsReceiver), _modulesData.optionsReceiverModule);
        _setModule(uint8(ITOFT.Module.TOFTGenericReceiver), _modulesData.genericReceiverModule);

        vault.claimOwnership();
    }

    /**
     * @dev Fallback function should handle calls made by endpoint, which should go to the receiver module.
     */
    fallback() external payable {
        /// @dev Call the receiver module on fallback, assume it's gonna be called by endpoint.
        _executeModule(uint8(ITOFT.Module.TOFTReceiver), msg.data, false);
    }

    receive() external payable {}

    /**
     * @dev Slightly modified version of the OFT _lzReceive() operation.
     * The composed message is sent to `address(this)` instead of `toAddress`.
     * @dev Internal function to handle the receive on the LayerZero endpoint.
     * @param _origin The origin information.
     *  - srcEid: The source chain endpoint ID.
     *  - sender: The sender address from the src chain.
     *  - nonce: The nonce of the LayerZero message.
     * @param _guid The unique identifier for the received LayerZero message.
     * @param _message The encoded message.
     * @dev _executor The address of the executor.
     * @dev _extraData Additional data.
     */
    function lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor, // @dev unused in the default implementation.
        bytes calldata _extraData // @dev unused in the default implementation.
    ) public payable override {
        // Call the internal OApp implementation of lzReceive.
        _executeModule(
            uint8(ITOFT.Module.TOFTReceiver),
            abi.encodeWithSelector(OAppReceiver.lzReceive.selector, _origin, _guid, _message, _executor, _extraData),
            false
        );
    }

    /**
     * @dev Slightly modified version of the OFT send() operation. Includes a `_msgType` parameter.
     * The `_buildMsgAndOptionsByType()` appends the packet type to the message.
     * @dev Executes the send operation.
     * @param _lzSendParam The parameters for the send operation.
     *      - _sendParam: The parameters for the send operation.
     *          - dstEid::uint32: Destination endpoint ID.
     *          - to::bytes32: Recipient address.
     *          - amountToSendLD::uint256: Amount to send in local decimals.
     *          - minAmountToCreditLD::uint256: Minimum amount to credit in local decimals.
     *      - _fee: The calculated fee for the send() operation.
     *          - nativeFee::uint256: The native fee.
     *          - lzTokenFee::uint256: The lzToken fee.
     *      - _extraOptions::bytes: Additional options for the send() operation.
     *      - refundAddress::address: The address to refund the native fee to.
     * @param _composeMsg The composed message for the send() operation. Is a combination of 1 or more TAP specific messages.
     *
     * @return msgReceipt The receipt for the send operation.
     *      - guid::bytes32: The unique identifier for the sent message.
     *      - nonce::uint64: The nonce of the sent message.
     *      - fee: The LayerZero fee incurred for the message.
     *          - nativeFee::uint256: The native fee.
     *          - lzTokenFee::uint256: The lzToken fee.
     * @return oftReceipt The OFT receipt information.
     *      - amountDebitLD::uint256: Amount of tokens ACTUALLY debited in local decimals.
     *      - amountCreditLD::uint256: Amount of tokens to be credited on the remote side.
     */
    function sendPacket(LZSendParam calldata _lzSendParam, bytes calldata _composeMsg)
        public
        payable
        whenNotPaused
        returns (
            MessagingReceipt memory msgReceipt,
            OFTReceipt memory oftReceipt,
            bytes memory msgSent,
            bytes memory options
        )
    {
        (msgReceipt, oftReceipt, msgSent, options) = abi.decode(
            _executeModule(
                uint8(ITOFT.Module.TOFTSender),
                abi.encodeCall(TapiocaOmnichainSender.sendPacket, (_lzSendParam, _composeMsg)),
                false
            ),
            (MessagingReceipt, OFTReceipt, bytes, bytes)
        );
    }

    /**
     * @dev See `TapiocaOmnichainSender.sendPacket`
     */
    function sendPacketFrom(address _from, LZSendParam calldata _lzSendParam, bytes calldata _composeMsg)
        public
        payable
        whenNotPaused
        returns (
            MessagingReceipt memory msgReceipt,
            OFTReceipt memory oftReceipt,
            bytes memory msgSent,
            bytes memory options
        )
    {
        (msgReceipt, oftReceipt, msgSent, options) = abi.decode(
            _executeModule(
                uint8(ITOFT.Module.TOFTSender),
                abi.encodeCall(TapiocaOmnichainSender.sendPacketFrom, (_from, _lzSendParam, _composeMsg)),
                false
            ),
            (MessagingReceipt, OFTReceipt, bytes, bytes)
        );
    }

    /**
     * See `OFTCore::send()`
     * @dev override default `send` behavior to add `whenNotPaused` modifier
     */
    function send(SendParam calldata _sendParam, MessagingFee calldata _fee, address _refundAddress)
        external
        payable
        override(OFTCore)
        whenNotPaused
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt)
    {
        // @dev Applies the token transfers regarding this send() operation.
        // - amountSentLD is the amount in local decimals that was ACTUALLY sent/debited from the sender.
        // - amountReceivedLD is the amount in local decimals that will be received/credited to the recipient on the remote OFT instance.
        (uint256 amountSentLD, uint256 amountReceivedLD) =
            _debit(msg.sender, _sendParam.amountLD, _sendParam.minAmountLD, _sendParam.dstEid);

        // @dev Builds the options and OFT message to quote in the endpoint.
        (bytes memory message, bytes memory options) = _buildMsgAndOptions(_sendParam, amountReceivedLD);

        // @dev Sends the message to the LayerZero endpoint and returns the LayerZero msg receipt.
        msgReceipt = _lzSend(_sendParam.dstEid, message, options, _fee, _refundAddress);
        // @dev Formulate the OFT receipt.
        oftReceipt = OFTReceipt(amountSentLD, amountReceivedLD);

        emit OFTSent(msgReceipt.guid, _sendParam.dstEid, msg.sender, amountSentLD, amountReceivedLD);
    }

    /// =====================
    /// View
    /// =====================

    /**
     * @notice returns token's decimals
     */
    function decimals() public pure override returns (uint8) {
        return 18;
    }

    /**
     * @dev Returns the hash of the struct used by the permit function.
     * @param _permitData Struct containing permit data.
     */
    function getTypedDataHash(ERC20PermitStruct calldata _permitData) public view returns (bytes32) {
        bytes32 permitTypeHash_ =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

        bytes32 structHash_ = keccak256(
            abi.encode(
                permitTypeHash_,
                _permitData.owner,
                _permitData.spender,
                _permitData.value,
                _permitData.nonce,
                _permitData.deadline
            )
        );
        return _hashTypedDataV4(structHash_);
    }

    /// =====================
    /// External
    /// =====================
    /**
     * @notice Wrap an ERC20.
     * @dev Minted amount is 1:1 with `_amount`
     * @param _fromAddress The address to wrap from.
     * @param _toAddress The address to wrap the ERC20 to.
     * @param _amount The amount of ERC20 to wrap.
     *
     * @return minted The tOFT minted amount.
     */
    function wrap(address _fromAddress, address _toAddress, uint256 _amount)
        external
        payable
        whenNotPaused
        nonReentrant
        onlyHostChain
        returns (uint256 minted)
    {
        if (erc20 == address(0)) {
            if (msg.value != _amount) revert TOFT_Failed();
            _wrapNative(_toAddress, _amount, 0);
        } else {
            if (msg.value > 0) revert TOFT_NotNative();
            _wrap(_fromAddress, _toAddress, _amount, 0);
        }

        return _amount; //no fee for TOFT
    }

    /// =====================
    /// Owner
    /// =====================
    /**
     * @notice rescues unused ETH from the contract
     * @param amount the amount to rescue
     * @param to the recipient
     */
    function rescueEth(uint256 amount, address to) external onlyOwner {
        (bool success,) = to.call{value: amount}("");
        if (!success) revert TOFT_Failed();
    }

    /// =====================
    /// Private
    /// =====================

    /**
     * @notice Unwrap an ERC20/Native with a 1:1 ratio. Called only on host chain.
     * @param _toAddress The address to wrap the ERC20 to.
     * @param _amount The amount of tokens to unwrap.
     */
    function unwrap(address _toAddress, uint256 _amount)
        external
        onlyHostChain
        nonReentrant
        returns (uint256 unwrapped)
    {
        _unwrap(msg.sender, _toAddress, _amount);
        return _amount;
    }

    /**
     * @notice Return the current chain EID.
     */
    function _getChainId() internal view override returns (uint32) {
        return IMessagingChannel(endpoint).eid();
    }
}
