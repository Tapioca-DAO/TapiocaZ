// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TOFTVault is Ownable {
    address private _token;
    bool private _isNative;

    // ************** //
    // *** ERRORS *** //
    // ************** //
    error NotValid();
    error ZeroAmount();
    error Failed();

    constructor(address token_) {
        _token = token_;
        _isNative = token_ == address(0);
    }

    function viewSupply() external view returns (uint256) {
        if (_isNative) {
            return address(this).balance;
        }
        return IERC20(_token).balanceOf(address(this));
    }

    function depositNative() external payable onlyOwner {
        if (!_isNative) revert NotValid();
        if (msg.value == 0) revert ZeroAmount();
    }

    function withdraw(address to, uint256 amount) external onlyOwner {
        if (_isNative) {
            (bool success, ) = to.call{value: amount}("");
            if (!success) revert Failed();
        } else {
            if (!IERC20(_token).transfer(to, amount)) revert Failed();
        }
    }

    receive() external payable {}
}
