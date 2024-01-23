// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {ExecutorOptions} from "@layerzerolabs/lz-evm-protocol-v2/contracts/messagelib/libs/ExecutorOptions.sol";
import {IOAppMsgInspector} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppMsgInspector.sol";
import {SendParam, MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";
import {BytesLib} from "solidity-bytes-utils/contracts/BytesLib.sol";

/////////       /////////
///////// TODO: move to periph for all repos
/////////       /////////
contract CommonOFTv2 is OFT {
    using BytesLib for bytes;

    constructor(string memory _name, string memory _symbol, address _endpoint, address _owner)
        OFT(_name, _symbol, _endpoint, _owner)
    {}

    /**
     * @dev public function to remove dust from the given local decimal amount.
     * @param _amountLD The amount in local decimals.
     * @return amountLD The amount after removing dust.
     *
     * @dev Prevents the loss of dust when moving amounts between chains with different decimals.
     * @dev eg. uint(123) with a conversion rate of 100 becomes uint(100).
     */
    function removeDust(uint256 _amountLD) public view virtual returns (uint256 amountLD) {
        return _removeDust(_amountLD);
    }

    /**
     * @dev Slightly modified version of the OFT quoteSend() operation. Includes a `_msgType` parameter.
     * The `_buildMsgAndOptionsByType()` appends the packet type to the message.
     * @notice Provides a quote for the send() operation.
     * @param _sendParam The parameters for the send() operation.
     * @param _extraOptions Additional options supplied by the caller to be used in the LayerZero message.
     * @param _payInLzToken Flag indicating whether the caller is paying in the LZ token.
     * @param _composeMsg The composed message for the send() operation.
     * @dev _oftCmd The OFT command to be executed.
     * @return msgFee The calculated LayerZero messaging fee from the send() operation.
     *
     * @dev MessagingFee: LayerZero msg fee
     *  - nativeFee: The native fee.
     *  - lzTokenFee: The lzToken fee.
     */
    function quoteSendPacket(
        SendParam calldata _sendParam,
        bytes calldata _extraOptions,
        bool _payInLzToken,
        bytes calldata _composeMsg,
        bytes calldata /*_oftCmd*/ // @dev unused in the default implementation.
    ) external view virtual returns (MessagingFee memory msgFee) {
        // @dev mock the amount to credit, this is the same operation used in the send().
        // The quote is as similar as possible to the actual send() operation.
        (, uint256 amountToCreditLD) =
            _debitView(_sendParam.amountToSendLD, _sendParam.minAmountToCreditLD, _sendParam.dstEid);

        // @dev Builds the options and OFT message to quote in the endpoint.
        (bytes memory message, bytes memory options) =
            _buildOFTMsgAndOptions(_sendParam, _extraOptions, _composeMsg, amountToCreditLD, address(0), false);

        // @dev Calculates the LayerZero fee for the send() operation.
        return _quote(_sendParam.dstEid, message, options, _payInLzToken);
    }

    /**
     * @notice Build an OFT message and option. The message contain OFT related info such as the amount to credit and the recipient.
     * It also contains the `_composeMsg`, which is 1 or more TAP specific messages. See `_buildTapMsgAndOptions()`.
     * The option is an aggregation of the OFT message as well as the TAP messages.
     *
     * @dev _msgSender can be empty; it's going to use context `msg.sender`
     * @param _sendParam: The parameters for the send operation.
     *      - dstEid::uint32: Destination endpoint ID.
     *      - to::bytes32: Recipient address.
     *      - amountToSendLD::uint256: Amount to send in local decimals.
     *      - minAmountToCreditLD::uint256: Minimum amount to credit in local decimals.
     * @param _extraOptions Additional options for the send() operation. If `_composeMsg` not empty, the `_extraOptions` should also contain the aggregation of its options.
     * @param _composeMsg The composed message for the send() operation. Is a combination of 1 or more TAP specific messages.
     * @param _amountToCreditLD The amount to credit in local decimals.
     * @param _msgSender is used instead of using context `msg.sender`, to preserve context of the OFT call and use `msg.sender` of the source chain.
     *
     * @return message The encoded message.
     * @return options The combined LZ msgType + `_extraOptions` options.
     */
    function _buildOFTMsgAndOptions(
        SendParam memory _sendParam,
        bytes memory _extraOptions,
        bytes memory _composeMsg,
        uint256 _amountToCreditLD,
        address _msgSender,
        bool _doNotCombine
    ) internal view returns (bytes memory message, bytes memory options) {
        bool hasCompose;

        if (_msgSender == address(0)) {
            // @dev This generated message has the msg.sender encoded into the payload so the remote knows who the caller is.
            // @dev NOTE the returned message will append `msg.sender` only if the message is composed.
            // If it's the case, it'll add the `address(msg.sender)` at the `amountToCredit` offset.
            (message, hasCompose) = OFTMsgCodec.encode(
                _sendParam.to,
                _toSD(_amountToCreditLD),
                // @dev Must be include a non empty bytes if you want to compose, EVEN if you don't need it on the remote.
                // EVEN if you don't require an arbitrary payload to be sent... eg. '0x01'
                _composeMsg
            );
        } else {
            // @dev `_msgSender` is used instead of using context `msg.sender`, to preserve context of the OFT call and use `msg.sender` of the source chain.
            message = hasCompose
                ? abi.encodePacked(
                    _sendParam.to, _toSD(_amountToCreditLD), OFTMsgCodec.addressToBytes32(_msgSender), _composeMsg
                )
                : abi.encodePacked(_sendParam.to, _toSD(_amountToCreditLD));
        }

        // @dev Change the msg type depending if its composed or not.
        uint16 _msgType = hasCompose ? SEND_AND_CALL : SEND;
        if (_doNotCombine) {
            options = _extraOptions;
        } else {
            // @dev Combine the callers _extraOptions with the enforced options via the OAppOptionsType3.
            options = _combineOptions(_sendParam.dstEid, _msgType, _extraOptions);
        }

        // @dev Optionally inspect the message and options depending if the OApp owner has set a msg inspector.
        // @dev If it fails inspection, needs to revert in the implementation. ie. does not rely on return boolean
        if (msgInspector != address(0)) {
            IOAppMsgInspector(msgInspector).inspect(message, options);
        }
    }

    /**
     * @notice Combines options for a given endpoint and message type.
     * @param _eid The endpoint ID.
     * @param _msgType The OAPP message type.
     * @param _extraOptions Additional options passed by the caller.
     * @return options The combination of caller specified options AND enforced options.
     *
     * @dev If there is an enforced lzReceive option:
     * - {gasLimit: 200k, msg.value: 1 ether} AND a caller supplies a lzReceive option: {gasLimit: 100k, msg.value: 0.5 ether}
     * - The resulting options will be {gasLimit: 300k, msg.value: 1.5 ether} when the message is executed on the remote lzReceive() function.
     * @dev This presence of duplicated options is handled off-chain in the verifier/executor.
     */
    function _combineOptions(uint32 _eid, uint16 _msgType, bytes memory _extraOptions)
        internal
        view
        virtual
        returns (bytes memory)
    {
        bytes memory enforced = enforcedOptions[_eid][_msgType];

        // No enforced options, pass whatever the caller supplied, even if it's empty or legacy type 1/2 options.
        if (enforced.length == 0) return _extraOptions;

        // No caller options, return enforced
        if (_extraOptions.length == 0) return enforced;

        // @dev If caller provided _extraOptions, must be type 3 as its the ONLY type that can be combined.
        if (_extraOptions.length >= 2) {
            uint16 optionsType = BytesLib.toUint16(BytesLib.slice(_extraOptions, 0, 2), 0);
            if (optionsType != OPTION_TYPE_3) {
                revert InvalidOptions(_extraOptions);
            }

            // @dev Remove the first 2 bytes containing the type from the _extraOptions and combine with enforced.
            return bytes.concat(enforced, BytesLib.slice(_extraOptions, 2, _extraOptions.length - 2));
        }

        // No valid set of options was found.
        revert InvalidOptions(_extraOptions);
    }

    /**
     * @dev Internal function to return the current EID.
     */
    function _getChainId() internal view virtual returns (uint32) {}
}
