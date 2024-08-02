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

