// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './OFT20/OFT.sol';

contract TapiocaOFT is OFT {
    ERC20 immutable erc20;
    uint8 _decimalCache;

    event Wrap(address indexed _from, address indexed _to, uint256 _amount);
    event Unwrap(address indexed _from, address indexed _to, uint256 _amount);

    constructor(
        string memory _name,
        string memory _symbol,
        address _lzEndpoint,
        ERC20 _erc20
    ) OFT(_name, _symbol, _lzEndpoint) {
        erc20 = _erc20;
        _decimalCache = erc20.decimals();
    }

    function decimals() public view override returns (uint8) {
        return _decimalCache;
    }

    /// @notice Wrap an ERC20 with a 1:1 ratio
    function wrap(address _toAddress, uint256 _amount) external {
        erc20.transferFrom(msg.sender, _toAddress, _amount);
        _mint(_toAddress, _amount);
        emit Wrap(msg.sender, _toAddress, _amount);
    }

    // @notice Unwrap an ERC20 with a 1:1 ratio
    function unwrap(address _toAddress, uint256 _amount) external {
        _burn(msg.sender, _amount);
        erc20.transfer(_toAddress, _amount);
        emit Unwrap(msg.sender, _toAddress, _amount);
    }
}
