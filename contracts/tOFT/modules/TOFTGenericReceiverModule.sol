// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

// Tapioca
import {ITOFT, TOFTInitStruct, SendParamsMsg} from "tapioca-periph/interfaces/oft/ITOFT.sol";
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
 * @title TOFTGenericReceiverModule
 * @author TapiocaDAO
 * @notice TOFT Generic module
 */
contract TOFTGenericReceiverModule is BaseTOFT {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;

    error TOFTGenericReceiverModule_NotAuthorized(address invalidAddress);
    error TOFTGenericReceiverModule_TransferFailed();

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

        msg_.amount = _toLD(msg_.amount.toUint64());

        if (msg_.unwrap) {
            ITOFT tOFT = ITOFT(address(this));
            address toftERC20 = tOFT.erc20();

            /// @dev xChain owner needs to have approved dst srcChain `sendPacket()` msg.sender in a previous composedMsg. Or be the same address.
            _internalTransferWithAllowance(msg_.receiver, srcChainSender, msg_.amount);
            tOFT.unwrap(address(this), msg_.amount);

            if (toftERC20 != address(0)) {
                IERC20(toftERC20).safeTransfer(msg_.receiver, msg_.amount);
            } else {
                (bool sent,) = msg_.receiver.call{value: msg_.amount}("");
                if (!sent) revert TOFTGenericReceiverModule_TransferFailed();
            }
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
