// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// Tapioca
import {TapiocaOmnichainSender} from "tap-utils/tapiocaOmnichainEngine/TapiocaOmnichainSender.sol";
import {ITOFT, TOFTInitStruct} from "tap-utils/interfaces/oft/ITOFT.sol";
import {BaseTOFT} from "../BaseTOFT.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

contract TOFTSender is BaseTOFT, TapiocaOmnichainSender {
    constructor(TOFTInitStruct memory _data) BaseTOFT(_data) {}
}
