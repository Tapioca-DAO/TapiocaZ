// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

//LZ
import {IMessagingChannel} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessagingChannel.sol";

// Tapioca
import {ITOFT, TOFTInitStruct, SendParamsMsg} from "tapioca-periph/interfaces/oft/ITOFT.sol";
import {TOFTMsgCodec} from "../libraries/TOFTMsgCodec.sol";
import {BaseTOFT} from "../BaseTOFT.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

/**
 * @title TOFTGenericReceiverModule
 * @author TapiocaDAO
 * @notice TOFT Generic module
 */
contract TOFTGenericReceiverModule is BaseTOFT {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    error TOFTGenericReceiverModule_NotAuthorized(address invalidAddress);
    error TOFTGenericReceiverModule_TransferFailed();
    error TOFTGenericReceiverModule_AmountMismatch();
    error TOFTGenericReceiverModule_OnlyHostChain();

    event WithParamsReceived(uint256 amount, address receiver, address srcChainSender);

    constructor(TOFTInitStruct memory _data) BaseTOFT(_data) {}

    /**
     * @notice Unwrap and sends underlying to `receiver`.
     *
     * @param srcChainSender The address of the sender on the source chain.
     * @param _data The call data containing info about the operation.
     *      - receiver::address: Underlying tokens receiver.
     *      - unwrap::bool: Unwrap TOFT.
     *      - amount::uint256: Amount to unwrap.
     */
    function receiveWithParamsReceiver(address srcChainSender, bytes memory _data) public payable {
        SendParamsMsg memory msg_ = TOFTMsgCodec.decodeSendParamsMsg(_data);

        /**
        * @dev validate data
        */
        msg_ = _validateReceiveWithParams(msg_);

        /**
        * @dev executes unwrap or revert
        */
        _unwrapInReceiveWithParams(msg_, srcChainSender);

        emit WithParamsReceived(msg_.amount, msg_.receiver, srcChainSender);
    }

    function _validateReceiveWithParams(SendParamsMsg memory msg_) private view returns (SendParamsMsg memory) {
        msg_.amount = _toLD(msg_.amount.toUint64());
        return msg_;
    }

    function _unwrapInReceiveWithParams(SendParamsMsg memory msg_, address srcChainSender) private {
        if (msg_.unwrap) {
            ITOFT tOFT = ITOFT(address(this));

            /// @dev xChain owner needs to have approved dst srcChain `sendPacket()` msg.sender in a previous composedMsg. Or be the same address.
            _internalTransferWithAllowance(msg_.receiver, srcChainSender, msg_.amount);

            if (IMessagingChannel(endpoint).eid() != hostEid) revert TOFTGenericReceiverModule_OnlyHostChain();
            _unwrap(address(this), msg_.receiver, msg_.amount);
        } else {
            if (msg.value > 0) revert TOFTGenericReceiverModule_AmountMismatch();
        }
    }
}
