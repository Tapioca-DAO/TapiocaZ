// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {MessagingReceipt, OFTReceipt, SendParam} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

// External
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol";

// Tapioca
import {ITapiocaOptionsBroker, ITapiocaOptionsBrokerCrossChain} from "tapioca-periph/contracts/interfaces/ITapiocaOptionsBroker.sol";
import {ITapiocaOFTBase} from "tapioca-periph/contracts/interfaces/ITapiocaOFT.sol";
import {TOFTInitStruct, SendParamsMsg} from "contracts/ITOFTv2.sol";
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
 * @title TOFTv2GenericReceiverModule
 * @author TapiocaDAO
 * @notice TOFTv2 Generic module
 */
contract TOFTv2GenericReceiverModule is BaseTOFTv2 {
    using SafeERC20 for IERC20;

    error TOFTv2GenericReceiverModule_NotAuthorized(address invalidAddress);
    error TOFTv2GenericReceiverModule_TransferFailed();

    constructor(TOFTInitStruct memory _data) BaseTOFTv2(_data) {}

    /**
     * @notice Might unwrap and send underlying to `receiver`
     * @param _data The call data containing info about the operation.
     *      - receiver::address: Underlying tokens receiver.
     *      - unwrap::bool: Unwrap TOFT.
     *      - amount::uint256: Amount to unwrap.
     */
    function receiveWithParamsReceiver(
        address srcChainSender,
        bytes memory _data
    ) public {
        _sanitizeSender();

        SendParamsMsg memory msg_ = TOFTMsgCoder.decodeSendParamsMsg(_data);

        if (msg_.unwrap) {
            ITapiocaOFTBase tOFT = ITapiocaOFTBase(address(this));
            address toftERC20 = tOFT.erc20();

            /// @dev xChain owner needs to have approved dst srcChain `sendPacket()` msg.sender in a previous composedMsg. Or be the same address.
            _internalTransferWithAllowance(
                msg_.receiver,
                srcChainSender,
                msg_.amount
            );
            tOFT.unwrap(address(this), msg_.amount);

            if (toftERC20 != address(0)) {
                IERC20(toftERC20).safeTransfer(msg_.receiver, msg_.amount);
            } else {
                (bool sent, ) = msg_.receiver.call{value: msg_.amount}("");
                if (!sent) revert TOFTv2GenericReceiverModule_TransferFailed();
            }
        }
    }

    function _internalTransferWithAllowance(
        address _owner,
        address srcChainSender,
        uint256 _amount
    ) internal {
        if (_owner != srcChainSender) {
            _spendAllowance(_owner, srcChainSender, _amount);
        }

        _transfer(_owner, address(this), _amount);
    }

    function _sanitizeSender() private view {
        if (msg.sender != address(endpoint))
            revert TOFTv2GenericReceiverModule_NotAuthorized(msg.sender);
    }
}
