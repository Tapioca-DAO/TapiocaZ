// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import 'hardhat/console.sol';

contract YieldBoxMock {
    mapping(address => uint256) public balances;
    mapping(uint256 => address) public assets;

    function addAsset(uint256 assetId, address asset) external {
        assets[assetId] = asset;
    }

    function depositAsset(
        uint256 assetId,
        address from,
        address to,
        uint256 amount,
        uint256,
        uint256
    ) external returns (uint256 amountOut, uint256 shareOut) {
        require(
            ERC20(assets[assetId]).transferFrom(from, address(this), amount),
            'failed transfer'
        );
        balances[to] += amount;
        return (amount, amount);
    }

    function withdraw(
        uint256 assetId,
        address from,
        address to,
        uint256 amount,
        uint256
    ) external returns (uint256 amountOut, uint256 shareOut) {
        require(balances[from] >= amount, 'not enough');
        ERC20(assets[assetId]).transfer(to, amount);
        balances[from] -= amount;
        return (amount, amount);
    }
}
