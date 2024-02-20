// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// Tapioca
import {TOFTInitStruct, LeverageUpActionMsg, ITOFT} from "tapioca-periph/interfaces/oft/ITOFT.sol";
import {TOFTOptionsReceiverModule} from "./TOFTOptionsReceiverModule.sol";
import {TOFTMarketReceiverModule} from "./TOFTMarketReceiverModule.sol";
import {BaseTOFTReceiver} from "./BaseTOFTReceiver.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

contract mTOFTReceiver is BaseTOFTReceiver {
    constructor(TOFTInitStruct memory _data) BaseTOFTReceiver(_data) {}

    function _toftCustomComposeReceiver(uint16 _msgType, address, bytes memory _toeComposeMsg)
        internal
        override
        returns (bool success)
    {
        if (_msgType == MSG_LEVERAGE_UP) {
            _executeModule(
                uint8(ITOFT.Module.TOFTMarketReceiver),
                abi.encodeWithSelector(TOFTMarketReceiverModule.leverageUpReceiver.selector, _toeComposeMsg),
                false
            );
            return true;
        } else if (_msgType == MSG_XCHAIN_LEND_XCHAIN_LOCK) {
            _executeModule(
                uint8(ITOFT.Module.TOFTOptionsReceiver),
                abi.encodeWithSelector(
                    TOFTOptionsReceiverModule.mintLendXChainSGLXChainLockAndParticipateReceiver.selector, _toeComposeMsg
                ),
                false
            );
        } else {
            return false;
        }
    }
}
