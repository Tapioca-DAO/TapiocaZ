// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TOFTVault} from "../contracts/tOFT/TOFTVault.sol";
import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";
import {ERC20Mock} from "./ERC20Mock.sol";
/**
 * @title TOFTVaultTest
 * @dev Unit tests for the TOFTVault contract
 */

contract TOFTVaultTest is Test {
    TOFTVault tOFTVault; //Instance for a vault with native tokens
    TOFTVault tOFTVaultERC20; //Instance for a vault with ERC20
    ERC20Mock erc20Mock;

    address owner;
    address userA;

    uint256 constant AMOUNT_NATIVE_TOKEN = 1000 ether;
    uint256 constant AMOUNT_MOCKERC20_TOKEN = 1000e18;
    /**
     * @dev Sets up the test environment by deploying the TOFTVault contract and allocating ether to the vault and the owner.
     */

    function setUp() public {
        tOFTVault = new TOFTVault(address(0));
        erc20Mock = new ERC20Mock("TapTest", "TT");
        tOFTVaultERC20 = new TOFTVault(address(erc20Mock));
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

    function test_claimOwnership() public {
        ///finished
        vm.startPrank(owner);
        tOFTVault.claimOwnership();
        assertEq(owner, tOFTVault.owner());
        vm.stopPrank();
    }

    function test_registerFees() public ownershipClaimedNative {
        //finished
        vm.startPrank(owner);
        uint256 amountFee = 5e18;
        tOFTVault.registerFees{value: amountFee}(amountFee);
        assertEq(amountFee, tOFTVault.viewFees());
        vm.stopPrank();
    }

    function test_transferFees() public ownershipClaimedNative addFees {
        vm.startPrank(owner);

        uint256 feesBeforeTransfer = tOFTVault.viewFees();
        uint256 transferAmount = 1 ether;
        tOFTVault.transferFees(userA, transferAmount);
        uint256 feesAfterTransfer = tOFTVault.viewFees();

        assertEq(feesAfterTransfer, feesBeforeTransfer - transferAmount);
        vm.stopPrank();
    }

    function test_depositNative() public ownershipClaimedNative {
        //finished
        vm.startPrank(owner);
        uint256 balanceInVault = address(tOFTVault).balance;
        uint256 amountToDeposit = 5 ether;
        tOFTVault.depositNative{value: amountToDeposit}();
        assertEq(address(tOFTVault).balance, balanceInVault + amountToDeposit);
        vm.stopPrank();
    }

    function test_withdraw() public ownershipClaimedNative {
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
     * Requires ownership to be claimed first.
     */
    function test_modifier_onlyOwner() public ownershipClaimedNative addFees {
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
    //////////An ERC20 Vault ////////////
    ////////////////////////////////////
    function test_claimOwnership_erc20() public {
        vm.startPrank(owner);
        tOFTVaultERC20.claimOwnership();
        assertEq(owner, tOFTVaultERC20.owner());
        vm.stopPrank();
    }

    function test_viewSupply_erc20() public {
        vm.startPrank(owner);
        tOFTVaultERC20.viewSupply();
        tOFTVaultERC20.owner(); //check function for the owner. Gonna be deleted
    }

    /////////////////////////////////////
    ///////////// modifier /////////////
    ////////////////////////////////////

    /**
     * @dev Claims ownership before executing the function.
     */
    modifier ownershipClaimedNative() {
        tOFTVault.claimOwnership();
        _;
    }

    modifier ownershipClaimedERC20() {
        tOFTVaultERC20.claimOwnership();
        _;
    }

    /**
     * @dev Adds fees to the vault before executing the function.
     */
    modifier addFees() {
        uint256 amountFee = 5e18;
        tOFTVault.registerFees{value: amountFee}(amountFee);
        _;
    }
}
