// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

// Tapioca
import {ERC721Permit} from "tapioca-sdk/dist/contracts/util/ERC4494.sol";
import {ERC721PermitStruct} from "contracts/ITOFTv2.sol";

contract ERC721Mock is ERC721, ERC721Permit {
    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) ERC721Permit(name_) {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    /**
     * @dev Returns the hash of the struct used by the permit function.
     * @param _permitData Struct containing permit data.
     */
    function getTypedDataHash(ERC721PermitStruct calldata _permitData) public view returns (bytes32) {
        bytes32 permitTypeHash_ = keccak256("Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)");

        bytes32 structHash_ = keccak256(
            abi.encode(
                permitTypeHash_, _permitData.spender, _permitData.tokenId, _permitData.nonce, _permitData.deadline
            )
        );
        return _hashTypedDataV4(structHash_);
    }
}
