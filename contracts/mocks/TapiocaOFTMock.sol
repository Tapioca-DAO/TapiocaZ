// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '../TapiocaOFT.sol';

contract TapiocaOFTMock is TapiocaOFT {
    uint256 chainId;

    constructor(
        address _lzEndpoint,
        ERC20 _erc20,
        uint8 _mainChainID
    ) TapiocaOFT(_lzEndpoint, _erc20, _mainChainID) {}

    function setChainId(uint256 _chainId) public {
        chainId = _chainId;
    }

    function getChainId() internal view override returns (uint256) {
        return chainId;
    }
}
