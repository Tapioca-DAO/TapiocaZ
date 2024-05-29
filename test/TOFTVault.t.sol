// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TOFTVault} from "../contracts/tOFT/TOFTVault.sol";
import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "./ERC20Mock.sol";
/**
 * @title TOFTVaultTest
 * @dev Unit tests for the TOFTVault contract
 * @notice This contract tests the TOFTVault contract with two types of vaults: one for native tokens and one for ERC20 tokens.
 */

contract TOFTVaultTest is Test {
    TOFTVault tOFTVault; //Instance for a vault with native tokens
    TOFTVault tOFTVaultERC20; //Instance for a vault with ERC20
    ERC20Mock erc20Mock;

    address owner;
    address userA;

    uint256 constant AMOUNT_NATIVE_TOKEN = 1000 ether;
    uint256 constant AMOUNT_MOCKERC20_TOKEN = 1000e18;
    uint256 constant AMOUNT_REGISTER_FEE = 1e18;
    /**
     * @dev Sets up the test environment by deploying the TOFTVault contract for both native tokens and ERC20 tokens.
     * Allocating ether to the native vault, and minting erc20Mock for the ERC20 vault.
     */

    function setUp() public {
        tOFTVault = new TOFTVault(address(0)); //native vault
        erc20Mock = new ERC20Mock("TapTest", "TT");
        tOFTVaultERC20 = new TOFTVault(address(erc20Mock)); //ERC20 vault
        erc20Mock.mint(address(tOFTVaultERC20), AMOUNT_MOCKERC20_TOKEN);

        owner = address(this);
        userA = address(1);

        vm.label(owner, "Owner");
        vm.label(userA, "User");

        vm.deal(address(tOFTVault), AMOUNT_NATIVE_TOKEN);
        vm.deal(owner, 15 ether);
        vm.deal(userA, 5 ether);
    }
    /**
     * @dev Tests if the ownership of the TOFTVault is claimable while the owner is address(0).
     */

    function test_claimOwnership_native() public {
        vm.startPrank(owner);
        tOFTVault.claimOwnership();
        assertEq(owner, tOFTVault.owner());
        vm.stopPrank();
    }
    /**
     * @dev Tests registering fees in the TOFTVault contract with native tokens.
     */

    function test_registerFees_native() public ownershipClaimed(tOFTVault) {
        vm.startPrank(owner);
        tOFTVault.registerFees{value: AMOUNT_REGISTER_FEE}(AMOUNT_REGISTER_FEE);
        assertEq(AMOUNT_REGISTER_FEE, tOFTVault.viewFees());
        vm.stopPrank();
    }
    /**
     * @dev Tests transferring fees in the TOFTVault contract with native tokens.
     */

    function test_transferFees_native() public ownershipClaimed(tOFTVault) addFees(tOFTVault) {
        vm.startPrank(owner);

        uint256 feesBeforeTransfer = tOFTVault.viewFees();
        uint256 amountFee = 1 ether;
        tOFTVault.transferFees(userA, amountFee);
        uint256 feesAfterTransfer = tOFTVault.viewFees();

        assertEq(feesAfterTransfer, feesBeforeTransfer - amountFee);
        vm.stopPrank();
    }
    /**
     * @dev Tests depositing native tokens in the TOFTVault contract.
     */

    function test_depositNative_native() public ownershipClaimed(tOFTVault) {
        vm.startPrank(owner);

        uint256 balanceInVault = address(tOFTVault).balance;
        uint256 amountToDeposit = 5 ether;

        tOFTVault.depositNative{value: amountToDeposit}();

        assertEq(address(tOFTVault).balance, balanceInVault + amountToDeposit);
        vm.stopPrank();
    }

    /**
     * @dev Tests withdrawing native tokens from the TOFTVault contract.
     */
    function test_withdraw_native() public ownershipClaimed(tOFTVault) {
        vm.startPrank(owner);

        uint256 amountToWithdraw = 5 ether;
        uint256 balanceInVaultBeforeWithdraw = address(tOFTVault).balance;

        tOFTVault.withdraw(userA, amountToWithdraw);

        uint256 balanceInVaultAfterWithdraw = address(tOFTVault).balance;
        assertEq(balanceInVaultAfterWithdraw, balanceInVaultBeforeWithdraw - amountToWithdraw);

        vm.stopPrank();
    }

    /**
     * @dev Tests the onlyOwner modifier by attempting to call functions as a non-owner.
     *
     */
    function test_modifier_onlyOwner_native() public ownershipClaimed(tOFTVault) addFees(tOFTVault) {
        vm.startPrank(userA);
        uint256 amount = 1 ether;

        vm.expectRevert("Ownable: caller is not the owner");
        tOFTVault.registerFees{value: amount}(amount);
        vm.expectRevert("Ownable: caller is not the owner");
        tOFTVault.transferFees(userA, amount);
        vm.expectRevert("Ownable: caller is not the owner");
        tOFTVault.depositNative{value: amount}();
        vm.expectRevert("Ownable: caller is not the owner");
        tOFTVault.withdraw(userA, amount);

        vm.stopPrank();
    }

    /////////////////////////////////////
    //////////// ERC20 Vault ////////////
    ////////////////////////////////////

    /**
     * @dev Tests if the ownership of the TOFTVaultERC20 is claimable while the owner is address(0).
     * @notice Tests claiming ownership of the ERC20 token vault.
     */
    function test_claimOwnership_erc20() public {
        vm.startPrank(owner);
        tOFTVaultERC20.claimOwnership();
        assertEq(owner, tOFTVaultERC20.owner());
        vm.stopPrank();
    }

    /**
     * @dev Tests viewing the supply of the ERC20 token in the TOFTVaultERC20 contract.
     */
    function test_viewSupply_erc20() public {
        vm.startPrank(userA);
        assertEq(tOFTVaultERC20.viewSupply(), AMOUNT_MOCKERC20_TOKEN);
        vm.stopPrank();
    }

    /**
     * @dev Tests viewing the total supply including fees of the ERC20 token in the TOFTVaultERC20 contract.
     */
    function test_viewTotalSupply_erc20() public ownershipClaimed(tOFTVaultERC20) addFees(tOFTVaultERC20) {
        vm.startPrank(userA);
        tOFTVaultERC20.viewTotalSupply();
        assertEq(tOFTVaultERC20.viewTotalSupply(), tOFTVaultERC20.viewSupply() + tOFTVaultERC20.viewFees());
        // console.log("Total supp is : ", tOFTVaultERC20.viewTotalSupply());
        // console.log("Supply is : ", tOFTVaultERC20.viewSupply());
        // console.log("Fees are : ", tOFTVaultERC20.viewFees());
        vm.stopPrank();

        //
    }

    /**
     * @dev Tests depositing native tokens in the TOFTVaultERC20 contract, expecting a revert.
     * @notice Tests that depositing native tokens in the ERC20 token vault reverts.
     */
    function test_depositNative_expect_revert() public ownershipClaimed(tOFTVaultERC20) {
        //finished
        vm.startPrank(owner);
        uint256 balanceInVault = address(tOFTVaultERC20).balance;
        uint256 amountToDeposit = 5 ether;
        vm.expectRevert(abi.encodeWithSignature("NotValid()"));
        tOFTVaultERC20.depositNative{value: amountToDeposit}();
        vm.stopPrank();
    }

    /**
     * @dev Tests registering fees in the TOFTVaultERC20 contract with ERC20 tokens.
     */
    function test_registerFees_erc20() public ownershipClaimed(tOFTVaultERC20) {
        vm.startPrank(owner);

        tOFTVaultERC20.registerFees{value: AMOUNT_REGISTER_FEE}(AMOUNT_REGISTER_FEE);
        assertEq(AMOUNT_REGISTER_FEE, tOFTVaultERC20.viewFees());
        vm.stopPrank();
    }

    /**
     * @dev Tests transferring fees in the TOFTVaultERC20 contract with ERC20 tokens.
     */
    function test_transferFees_erc20() public ownershipClaimed(tOFTVaultERC20) addFees(tOFTVaultERC20) {
        vm.startPrank(owner);

        uint256 feesBeforeTransfer = tOFTVaultERC20.viewFees();
        uint256 amountFee = 1 ether;
        tOFTVaultERC20.transferFees(userA, amountFee);
        uint256 feesAfterTransfer = tOFTVaultERC20.viewFees();

        assertEq(feesAfterTransfer, feesBeforeTransfer - amountFee);
        vm.stopPrank();
    }

    /**
     * @dev Tests withdrawing ERC20 tokens from the TOFTVaultERC20 contract.
     */
    function test_withdraw_erc20() public ownershipClaimed(tOFTVaultERC20) {
        vm.startPrank(owner);

        uint256 amountToWithdraw = 5e18;
        uint256 balanceInVaultBeforeWithdraw = erc20Mock.balanceOf(address(tOFTVaultERC20));

        tOFTVaultERC20.withdraw(userA, amountToWithdraw);

        uint256 balanceInVaultAfterWithdraw = erc20Mock.balanceOf(address(tOFTVaultERC20));
        assertEq(balanceInVaultAfterWithdraw, balanceInVaultBeforeWithdraw - amountToWithdraw);

        vm.stopPrank();
    }

    /////////////////////////////////////
    ///////////// modifier /////////////
    ////////////////////////////////////

    /**
     * @dev Claims ownership.
     */
    modifier ownershipClaimed(TOFTVault _tOFTVault) {
        _tOFTVault.claimOwnership();
        _;
    }

    /**
     * @dev Adds fees to the vault before.
     */
    modifier addFees(TOFTVault _tOFTVault) {
        _tOFTVault.registerFees{value: AMOUNT_REGISTER_FEE}(AMOUNT_REGISTER_FEE);
        _;
    }
}
