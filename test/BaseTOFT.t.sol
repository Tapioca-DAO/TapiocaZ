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

