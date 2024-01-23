// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

//LZ
import {IMessagingChannel} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessagingChannel.sol";
import {MessagingReceipt, OFTReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OAppReceiver} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppReceiver.sol";
import {Origin} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";

// External
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

// Tapioca
import {ITOFTv2, TOFTInitStruct, TOFTModulesInitStruct, LZSendParam, ERC20PermitStruct} from "contracts/ITOFTv2.sol";
import {TOFTv2Receiver} from "contracts/modules/TOFTv2Receiver.sol";
import {TOFTv2Sender} from "contracts/modules/TOFTv2Sender.sol";
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

/**
 * @title TOFTv2
 * @author TapiocaDAO
 * @notice Tapioca OFT wrapper contract
 * @dev It can be wrapped and unwrapped only on host chain
 */
contract TOFTv2 is BaseTOFTv2, Pausable, ReentrancyGuard, ERC20Permit {
    error TOFTV2_OnlyHostChain();
    error TOFTV2_NotNative();

    modifier onlyHostChain() {
        if (_getChainId() != hostEid) revert TOFTV2_OnlyHostChain();
        _;
    }

    constructor(TOFTInitStruct memory _tOFTData, TOFTModulesInitStruct memory _modulesData)
        BaseTOFTv2(_tOFTData)
        ERC20Permit(_tOFTData.name)
    {
        // Set TOFTv2 execution modules
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

        _setModule(uint8(ITOFTv2.Module.TOFTv2Sender), _modulesData.tOFTSenderModule);
        _setModule(uint8(ITOFTv2.Module.TOFTv2Receiver), _modulesData.tOFTReceiverModule);
        _setModule(uint8(ITOFTv2.Module.TOFTv2MarketReceiver), _modulesData.marketReceiverModule);
        _setModule(uint8(ITOFTv2.Module.TOFTv2OptionsReceiver), _modulesData.optionsReceiverModule);
        _setModule(uint8(ITOFTv2.Module.TOFTv2GenericReceiver), _modulesData.genericReceiverModule);
    }

    /**
     * @dev Fallback function should handle calls made by endpoint, which should go to the receiver module.
     */
    fallback() external payable {
        /// @dev Call the receiver module on fallback, assume it's gonna be called by endpoint.
        _executeModule(uint8(ITOFTv2.Module.TOFTv2Receiver), msg.data, false);
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
            uint8(ITOFTv2.Module.TOFTv2Receiver),
            abi.encodeWithSelector(OAppReceiver.lzReceive.selector, _origin, _guid, _message, _executor, _extraData),
            false
        );
    }

    /**
     * @notice Execute a call to a module.
     * @dev Example on how `_data` should be encoded:
     *      - abi.encodeCall(IERC20.transfer, (to, amount));
     * @dev Use abi.encodeCall to encode the function call and its parameters with type safety.
     *
     * @param _module The module to execute.
     * @param _data The data to execute. Should be ABI encoded with the selector.
     * @param _forwardRevert If true, forward the revert message from the module.
     *
     * @return returnData The return data from the module execution, if any.
     */
    function executeModule(ITOFTv2.Module _module, bytes memory _data, bool _forwardRevert)
        external
        payable
        returns (bytes memory returnData)
    {
        return _executeModule(uint8(_module), _data, _forwardRevert);
    }

    /// ========================
    /// Frequently used modules
    /// ========================

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
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt)
    {
        (msgReceipt, oftReceipt) = abi.decode(
            _executeModule(
                uint8(ITOFTv2.Module.TOFTv2Sender),
                abi.encodeCall(TOFTv2Sender.sendPacket, (_lzSendParam, _composeMsg)),
                false
            ),
            (MessagingReceipt, OFTReceipt)
        );
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
     * @return minted The tOFTv2 minted amount.
     */
    function wrap(address _fromAddress, address _toAddress, uint256 _amount)
        external
        payable
        nonReentrant
        onlyHostChain
        returns (uint256 minted)
    {
        if (erc20 == address(0)) {
            _wrapNative(_toAddress, _amount, 0);
        } else {
            if (msg.value > 0) revert TOFTV2_NotNative();
            _wrap(_fromAddress, _toAddress, _amount, 0);
        }

        return _amount; //no fee for TOFT
    }

    /**
     * @notice Unwrap an ERC20/Native with a 1:1 ratio. Called only on host chain.
     * @param _toAddress The address to wrap the ERC20 to.
     * @param _amount The amount of tokens to unwrap.
     */
    function unwrap(address _toAddress, uint256 _amount) external onlyHostChain nonReentrant {
        _unwrap(_toAddress, _amount);
    }
}
