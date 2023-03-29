// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "../BaseTOFT.sol";

contract TapiocaOFTMock is BaseTOFT {
    constructor(
        address _lzEndpoint,
        bool _isNative,
        IERC20 _erc20,
        IYieldBox _yieldBox,
        string memory _name,
        string memory _symbol,
        uint8 _decimal,
        uint256 _hostChainID
    )
        BaseTOFT(
            _lzEndpoint,
            _isNative,
            _erc20,
            _yieldBox,
            _name,
            _symbol,
            _decimal,
            _hostChainID,
            ITapiocaWrapper(msg.sender)
        )
    {}

    function freeMint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}
