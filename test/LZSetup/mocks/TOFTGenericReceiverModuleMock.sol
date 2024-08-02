// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TOFTGenericReceiverModule} from "../../../contracts/tOFT/modules/TOFTGenericReceiverModule.sol";
import {TOFTInitStruct, SendParamsMsg} from "tapioca-periph/interfaces/oft/ITOFT.sol";

contract TOFTGenericReceiverModuleMock is TOFTGenericReceiverModule {
    constructor(TOFTInitStruct memory _data) TOFTGenericReceiverModule(_data) {}

    function mint(uint256 amount, address receiver) public {
        _mint(receiver, amount);
    }

    //helper function to get local deicmal conversion of amount
    function toLD(uint64 amount) public view returns (uint256) {
        return _toLD(amount);
    }
}
