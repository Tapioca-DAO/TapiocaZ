// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.22;

import {BaseTOFTMock} from "./LZSetup/mocks/BaseTOFTMock.sol";

import {ERC20Mock} from "./ERC20Mock.sol";
//tapioca
import {Pearlmit} from "../gitmodule/tapioca-periph/contracts/pearlmit/Pearlmit.sol";
import {Cluster} from "../gitmodule/tapioca-periph/contracts/Cluster/Cluster.sol";
import {YieldBox} from "../gitmodule/tap-yieldbox/contracts/YieldBox.sol";
import {IPearlmit} from "../gitmodule/tapioca-periph/contracts/interfaces/periph/IPearlmit.sol";
import {TOFTInitStruct} from "../gitmodule/tapioca-periph/contracts/interfaces/oft/ITOFT.sol";
import {TOFTVault} from "../contracts/tOFT/TOFTVault.sol";
import {TapiocaOmnichainExtExec} from "tapioca-periph/tapiocaOmnichainEngine/extension/TapiocaOmnichainExtExec.sol";
//test helper
import {TOFTTestHelper} from "./TOFTTestHelper.t.sol";
import {console} from "forge-std/console.sol";
contract BaseTOFTTest is TOFTTestHelper {
    error TOFT_AllowanceNotValid();
    error TOFT_NotValid();
    error TOFT_VaultWrongERC20();
    error TOFT_NotAuthorized();

    BaseTOFTMock baseTOFT; // TOFT with an ERC20 vault
    BaseTOFTMock baseTOFTNative; // TOFT with a native vault

    address public pearlmitAddress;
    address public owner;
    address public alice;
    address public bob;

    uint256 constant AMOUNT_TO_MINT = 10e18;

    Pearlmit pearlmit;
    Cluster cluster;
    YieldBox yieldBox;
    ERC20Mock erc20;
    TOFTVault toftVault;
    TOFTVault toftVaultNative;
    TapiocaOmnichainExtExec toftExtExec;

    function setUp() public virtual override {
        //// address setup ////
        pearlmitAddress = makeAddr("pearlmit");
        vm.label(pearlmitAddress, "PearlmitAddress");
        owner = makeAddr("owner");
        vm.label(owner, "Owner");
        alice = makeAddr("alice");
        vm.label(alice, "Alice");
        bob = makeAddr("bob");
        vm.label(bob, "Bob");
        //// contracts setup ////
        pearlmit = new Pearlmit("BaseTOFT", "1", pearlmitAddress, 0);
        cluster = new Cluster(1, owner);
        yieldBox = createYieldBox(pearlmit, owner);
        erc20 = new ERC20Mock("TOFT", "TOFT");
        toftVault = new TOFTVault(address(erc20));
        toftVaultNative = new TOFTVault(address(0));
        toftExtExec = new TapiocaOmnichainExtExec();
        //setup endpoint
        setUpEndpoints(3, LibraryType.UltraLightNode);
        //setup baseTOFT

        TOFTInitStruct memory toftDataErc20Vault = initTOFTData(address(erc20), address(toftVault));
        TOFTInitStruct memory toftDataNativeVault = initTOFTData(address(0), address(toftVaultNative));

        baseTOFT = new BaseTOFTMock(toftDataErc20Vault);
        vm.label(address(baseTOFT), "BaseTOFT");

        baseTOFTNative = new BaseTOFTMock(toftDataNativeVault);
        vm.label(address(baseTOFT), "BaseTOFTNative");

        //mint some tokens
        erc20.mint(alice, AMOUNT_TO_MINT);
    }

    function test_setPause() public {
        //test admin capabilities to pause and unpause
        vm.startPrank(address(owner));
        baseTOFT.setPause(true);
        assertTrue(baseTOFT.paused());
        baseTOFT.setPause(false);
        assertFalse(baseTOFT.paused());
        vm.stopPrank();
        //assert that a random address cannot pause or unpause
        vm.startPrank(alice);
        vm.expectRevert(TOFT_NotAuthorized.selector);
        baseTOFT.setPause(true);
        vm.expectRevert(TOFT_NotAuthorized.selector);
        baseTOFT.setPause(false);
    }

    function test_wrapSuccess() public {
        //test wrap function
        vm.startPrank(alice);
        uint256 aliceBalanceBefore = erc20.balanceOf(alice);
        uint200 amountToWrap = 1e18;
        assert(baseTOFT.balanceOf(alice) == 0);
        setApprovals(amountToWrap);
        baseTOFT.wrap_(alice, alice, amountToWrap, 0);

        uint256 aliceBalanceAfter = erc20.balanceOf(alice);
        uint256 balanceWrapToken = baseTOFT.balanceOf(alice);
        assertTrue(aliceBalanceAfter == aliceBalanceBefore - amountToWrap);
        assertTrue(balanceWrapToken == amountToWrap);
    }

    function test_wrapWithoutAllowance() public {
        vm.startPrank(alice);
        uint200 amountToWrap = 1e18;
        vm.expectRevert(TOFT_AllowanceNotValid.selector);
        baseTOFT.wrap_(bob, alice, amountToWrap, 0);
    }

    function test_wrapWithZeroAmount() public {
        vm.startPrank(alice);
        uint200 amountToWrap = 0;
        vm.expectRevert(TOFT_NotValid.selector);
        baseTOFT.wrap_(alice, alice, amountToWrap, 0);
    }

    function test_wrapNative() public {
        vm.startPrank(address(baseTOFTNative));
        toftVaultNative.claimOwnership();
        vm.stopPrank();

        vm.startPrank(alice);
        vm.deal(alice, 10 ether);
        uint256 amountToWrap = 1 ether;
        baseTOFTNative.wrapNative_{value: 1 ether}(address(owner), amountToWrap, 0);
        uint256 balanceWrapToken = baseTOFTNative.balanceOf(owner);
        assertTrue(balanceWrapToken == amountToWrap);
    }

    function test_unwrapSuccess() public {
        setVaultOwnership(address(baseTOFT));
        vm.startPrank(alice);
        uint200 tokenAmount = 1e18;

        setApprovals(tokenAmount);
        baseTOFT.wrap_(alice, alice, tokenAmount, 0);

        // Record Alice's ERC20 balance before unwrapping
        uint256 aliceERC20BalanceBefore = erc20.balanceOf(alice);

        // Unwrap tokens: Convert wrapped tokens back to ERC20 tokens
        baseTOFT.unwrap_(alice, alice, tokenAmount);

        // Record Alice's ERC20 balance after unwrapping
        uint256 aliceERC20BalanceAfter = erc20.balanceOf(alice);

        // Check Alice's wrapped token balance
        uint256 aliceWrappedTokenBalance = baseTOFT.balanceOf(alice);

        // Check Alice's final ERC20 token balance
        uint256 aliceFinalERC20Balance = erc20.balanceOf(alice);

        // Assert that Alice has no wrapped tokens left
        assertEq(aliceWrappedTokenBalance, 0, "Alice should have no wrapped tokens left");

        // Assert that Alice received back her ERC20 tokens
        assertEq(
            aliceFinalERC20Balance,
            aliceERC20BalanceBefore + tokenAmount,
            "Alice should have received back her ERC20 tokens"
        );
        vm.stopPrank();
    }

    /////////////////////////////////////////////
    //////////////Helper functions //////////////
    /////////////////////////////////////////////

    function setApprovals(uint200 _amount) public {
        uint48 deadline = uint48(block.timestamp);

        pearlmit.approve(20, address(erc20), 0, address(baseTOFT), _amount, deadline);
        erc20.approve(address(pearlmit), _amount);
    }

    //@dev this allow some modularity in the setup of the vault. It can be a native vault or an ERC20 vault
    function initTOFTData(address _erc20, address _vaultAddress) public view returns (TOFTInitStruct memory) {
        TOFTInitStruct memory toftData = TOFTInitStruct({
            name: "TOFT",
            symbol: "TOFT",
            endpoint: endpoints[1],
            delegate: address(owner),
            yieldBox: address(yieldBox),
            cluster: address(cluster),
            erc20: _erc20,
            vault: _vaultAddress,
            hostEid: 1,
            extExec: address(toftExtExec),
            pearlmit: IPearlmit(address(pearlmit))
        });

        return toftData;
    }

    function setVaultOwnership(address _owner) public {
        vm.startPrank(_owner);
        toftVault.claimOwnership();
        vm.stopPrank();
    }
}
