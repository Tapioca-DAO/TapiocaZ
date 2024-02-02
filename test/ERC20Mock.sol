// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Tapioca
import {ERC20PermitStruct} from "tapioca-periph/interfaces/oft/ITOFT.sol";

contract ERC20Mock is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
