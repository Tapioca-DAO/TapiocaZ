// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";

// Tapioca
import {TOFTInitStruct} from "tapioca-periph/interfaces/oft/ITOFT.sol";
import {BaseTOFTReceiver} from "./BaseTOFTReceiver.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

contract TOFTReceiver is BaseTOFTReceiver {
    constructor(TOFTInitStruct memory _data) BaseTOFTReceiver(_data) {}

    function _toftCustomComposeReceiver(uint16, address, bytes memory) internal pure override returns (bool success) {
        return false;
    }
}
