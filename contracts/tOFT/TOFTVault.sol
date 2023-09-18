// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TOFTVault is Ownable {
    address private _token;
    bool private _isNative;

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
        require(_isNative, "TOFTVault: different token");
        require(msg.value > 0, "TOFTVault: amount not valid");
    }

    function withdraw(address to, uint256 amount) external onlyOwner {
        if (_isNative) {
            (bool success, ) = to.call{value: amount}("");
            require(success, "TOFTVault: native transfer failed");
        } else {
            require(
                IERC20(_token).transfer(to, amount),
                "TOFTVault: transfer failed"
            );
        }
    }

    receive() external payable {}
}
