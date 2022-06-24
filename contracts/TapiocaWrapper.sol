// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
import './TapiocaOFT.sol';

import '@openzeppelin/contracts/utils/Create2.sol';
import '@rari-capital/solmate/src/auth/Owned.sol';

contract TapiocaWrapper is Owned {
    TapiocaOFT[] public tapiocaOFTs;

    constructor() Owned(msg.sender) {}

    function tapiocaOFTLength() public view returns (uint256) {
        return tapiocaOFTs.length;
    }

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

    function executeTOFT(address toft, bytes calldata bytecode)
        external
        payable
        onlyOwner
        returns (bool success)
    {
        (success, ) = payable(toft).call{value: msg.value}(bytecode);
    }
}
