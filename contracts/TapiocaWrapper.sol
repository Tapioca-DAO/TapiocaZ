// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
import './TapiocaOFT.sol';

import '@openzeppelin/contracts/utils/Create2.sol';
import '@rari-capital/solmate/src/auth/Owned.sol';

contract TapiocaWrapper is Owned {
    TapiocaOFT[] public tapiocaOFTs;
    uint256 public mngmtFee;
    uint256 public constant mngmtFeeFraction = 10000;

    constructor() Owned(msg.sender) {}

    function createTOFT(address erc20, bytes calldata bytecode)
        external
        onlyOwner
    {
        TapiocaOFT toft = TapiocaOFT(
            Create2.deploy(
                0,
                keccak256(abi.encodePacked(keccak256('TapiocaWrapper'), erc20)),
                bytecode
            )
        );
        tapiocaOFTs.push(toft);

        require(address(toft.erc20()) == erc20, 'ERC20 address mismatch');
    }

    // ========== TOFT ==========

    function executeTOFT(address toft, bytes calldata bytecode)
        external
        payable
        onlyOwner
        returns (bool success)
    {
        (success, ) = payable(toft).call{value: msg.value}(bytecode);
    }

    function tapiocaOFTLength() external view returns (uint256) {
        return tapiocaOFTs.length;
    }

    function lastTOFT() external view returns (TapiocaOFT) {
        return tapiocaOFTs[tapiocaOFTs.length - 1];
    }

    // ========== Management ==========
    function setMngmtFee(uint256 _mngmtFee) external onlyOwner {
        mngmtFee = _mngmtFee;
    }
}
