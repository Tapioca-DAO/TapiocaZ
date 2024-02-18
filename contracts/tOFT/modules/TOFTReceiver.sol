// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {OFTCore} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTCore.sol";
import {Origin} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";

// External
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Tapioca
import {TapiocaOmnichainReceiver} from "tapioca-periph/tapiocaOmnichainEngine/TapiocaOmnichainReceiver.sol";
import {ITOFT, TOFTInitStruct} from "tapioca-periph/interfaces/oft/ITOFT.sol";
import {TOFTGenericReceiverModule} from "./TOFTGenericReceiverModule.sol";
import {TOFTOptionsReceiverModule} from "./TOFTOptionsReceiverModule.sol";
import {TOFTMarketReceiverModule} from "./TOFTMarketReceiverModule.sol";
import {BaseTOFT} from "contracts/tOFT/BaseTOFT.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

contract TOFTReceiver is BaseTOFT, TapiocaOmnichainReceiver {
    using SafeERC20 for IERC20;

    constructor(TOFTInitStruct memory _data) BaseTOFT(_data) {}

    /**
     * @inheritdoc TapiocaOmnichainReceiver
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor, /*_executor*/ // @dev unused in the default implementation.
        bytes calldata _extraData /*_extraData*/ // @dev unused in the default implementation.
    ) internal virtual override(OFTCore, TapiocaOmnichainReceiver) {
        TapiocaOmnichainReceiver._lzReceive(_origin, _guid, _message, _executor, _extraData);
    }

    /**
     * @inheritdoc TapiocaOmnichainReceiver
     */
    function _toeComposeReceiver(uint16 _msgType, address _srcChainSender, bytes memory _toeComposeMsg)
        internal
        override
        returns (bool success)
    {
        if (_msgType == MSG_YB_SEND_SGL_BORROW) {
            _executeModule(
                uint8(ITOFT.Module.TOFTMarketReceiver),
                abi.encodeWithSelector(TOFTMarketReceiverModule.marketBorrowReceiver.selector, _toeComposeMsg),
                false
            );
        } else if (_msgType == MSG_MARKET_REMOVE_COLLATERAL) {
            _executeModule(
                uint8(ITOFT.Module.TOFTMarketReceiver),
                abi.encodeWithSelector(TOFTMarketReceiverModule.marketRemoveCollateralReceiver.selector, _toeComposeMsg),
                false
            );
        } else if (_msgType == MSG_TAP_EXERCISE) {
            _executeModule(
                uint8(ITOFT.Module.TOFTOptionsReceiver),
                abi.encodeWithSelector(
                    TOFTOptionsReceiverModule.exerciseOptionsReceiver.selector, _srcChainSender, _toeComposeMsg
                ),
                false
            );
        } else if (_msgType == MSG_SEND_PARAMS) {
            _executeModule(
                uint8(ITOFT.Module.TOFTGenericReceiver),
                abi.encodeWithSelector(
                    TOFTGenericReceiverModule.receiveWithParamsReceiver.selector, _srcChainSender, _toeComposeMsg
                ),
                false
            );
        } else if (_msgType == MSG_LOCK_AND_PARTICIPATE) {
            _executeModule(
                uint8(ITOFT.Module.TOFTOptionsReceiver),
                abi.encodeWithSelector(TOFTOptionsReceiverModule.lockAndParticipateReceiver.selector, _toeComposeMsg),
                false
            );
        } else {
            return false;
        }
        return true;
    }
}
