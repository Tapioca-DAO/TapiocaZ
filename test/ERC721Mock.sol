// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// Tapioca
import {ERC721Permit} from "contracts/util/ERC4494.sol";

contract ERC721Mock is ERC721, ERC721Permit {
    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) ERC721Permit(name_) {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }
}
