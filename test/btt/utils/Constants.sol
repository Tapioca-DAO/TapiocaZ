// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

/// @notice Helper contract containing constants for testing.
abstract contract Constants {
    // *************** //
    // *** GENERIC *** //
    // *************** //
    uint256 public constant SMALL_AMOUNT = 10 ether;
    uint256 public constant MEDIUM_AMOUNT = 100 ether;
    uint256 public constant LARGE_AMOUNT = 1000 ether;

    uint256 public constant LOW_DECIMALS_SMALL_AMOUNT = 10 * 1e6;
    uint256 public constant LOW_DECIMALS_MEDIUM_AMOUNT = 100 * 1e6;
    uint256 public constant LOW_DECIMALS_LARGE_AMOUNT = 1000 * 1e6;

    uint256 public constant USER_A_PKEY = 0x1;
    uint256 public constant USER_B_PKEY = 0x2;

    address public constant ADDRESS_ZERO = address(0);
    uint256 public constant VALUE_ZERO = 0;

    // **************** //
    // *** PEARLMIT *** //
    // **************** //
    /// @dev Constant value representing the ERC721 token type for signatures and transfer hooks
    uint256 constant TOKEN_TYPE_ERC721 = 721;
    /// @dev Constant value representing the ERC1155 token type for signatures and transfer hooks
    uint256 constant TOKEN_TYPE_ERC1155 = 1155;
    /// @dev Constant value representing the ERC20 token type for signatures and transfer hooks
    uint256 constant TOKEN_TYPE_ERC20 = 20;

    // ************* //
    // *** MTOFT *** //
    // ************* //
    uint256 constant DEFAULT_MINT_CAP = 1_000_000 * 1e18;
}