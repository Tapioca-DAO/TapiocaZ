// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {BaseTOFTTest} from "./BaseTOFT.t.sol";
import {console} from "forge-std/console.sol";

contract ModuleManagerTest is BaseTOFTTest {
    error ModuleManager__ModuleNotAuthorized();

    // module information for test purposes

    uint8 module = 1;
    address moduleAddress = address(0x123);

    function setUp() public override {
        super.setUp();
    }

    function test_set_module() public {
        // Set module
        address checkWhiteListBefore = whiteListedModule(module);
        console.log(checkWhiteListBefore);
        assertEq(checkWhiteListBefore, address(0), "No address should be set yet");
        baseTOFT.setModule_(module, moduleAddress);
        address checkWhiteListAfter = whiteListedModule(module);
        assertEq(checkWhiteListAfter, moduleAddress, "Module should be set correctly");
    }

    function test_extract_module_sucess() public {
        // Set module
        baseTOFT.setModule_(module, moduleAddress);
        // Extract module
        address extractedModule = baseTOFT.extractModule_(module);
        assertEq(extractedModule, moduleAddress,"Should extract module address correctly");
    }

    function test_extract_module_not_authorized() public {
        // Extract module
        vm.expectRevert(ModuleManager__ModuleNotAuthorized.selector);
        baseTOFT.extractModule_(0);
    }

