// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// Tapioca
import {TOFTInitStruct, LeverageUpActionMsg, ITOFT} from "tapioca-periph/interfaces/oft/ITOFT.sol";
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
                abi.encodeWithSelector(
                    TOFTMarketReceiverModule.leverageUpReceiver.selector, _toeComposeMsg
                ),
                false
            );
            return true;
        } else {
            return false;
        }
    }
}
