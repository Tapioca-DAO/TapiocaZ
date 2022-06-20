pragma solidity ^0.8.0;

import './OFT20/OFT.sol';

contract TapiocaOFT is OFT {
    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint
    ) public OFT(_name, _symbol, _lzEndpoint) {}
}
