// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {BaseTOFT} from "../../../contracts/tOFT/BaseTOFT.sol";
import {TOFTInitStruct} from "tapioca-periph/interfaces/oft/ITOFT.sol";

contract BaseTOFTMock is BaseTOFT {
    constructor(TOFTInitStruct memory _data) BaseTOFT(_data) {}

    function wrap_(address _fromAddress, address _toAddress, uint256 _amount, uint256 _feeAmount) public {
        _wrap(_fromAddress, _toAddress, _amount, _feeAmount);
    }

    function wrapNative_(address _toAddress, uint256 _amount, uint256 _feeAmount) public payable {
        _wrapNative(_toAddress, _amount, _feeAmount);
    }

    function unwrap_(address _fromAddress, address _toAddress, uint256 _amount) public {
        _unwrap(_fromAddress, _toAddress, _amount);
    }

    /// @notice These functions are used to test the module manager.

    function setModule_(uint8 _module, address _moduleAddress) public {
        _setModule(_module, _moduleAddress);
    }

    function extractModule_(uint8 _module) public view returns (address) {
        return _extractModule(_module);
    }

    function executeModule_(uint8 _module, bytes memory _data, bool _forwardRevert) public {
        _executeModule(_module, _data, _forwardRevert);
    }

    function whiteListedModule_(uint8 _module) public returns (address) {
        address whiteListedAddress = _moduleAddresses[_module];
        return whiteListedAddress;
    }
}
