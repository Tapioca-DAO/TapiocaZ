pragma solidity ^0.8.0;
import './TapiocaOFT.sol';

import '@rari-capital/solmate/src/auth/Owned.sol';

contract TapiocaWrapper is Owned {
    TapiocaOFT[] tapiocaOFTs;

    constructor() Owned(msg.sender) {}

    function createOFT(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        ERC20 _erc20
    ) external onlyOwner {
        tapiocaOFTs.push(new TapiocaOFT(_name, _symbol, _lzEndpoint, _erc20));
    }
}
