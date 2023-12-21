// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/console.sol";
import {Test, console2} from "forge-std/Test.sol";
import {Balancer} from "../../contracts/Balancer.sol";
import "../../gitsub_tapioca-sdk/src/contracts/mocks/ERC20Mock.sol";

contract BalancerTest is Test {
    Balancer public balancer;
    
    address public routerEth;
    address public router;

    ERC20Mock public token1;

    address public randomUser;

    uint256 public constant TOKEN_MINT_AMOUNT = 100 ether;

    function setUp() public {
        randomUser = address(uint160(uint(keccak256(abi.encodePacked(uint256(0), blockhash(block.number))))));


        routerEth = address(uint160(uint(keccak256(abi.encodePacked(uint256(1), blockhash(block.number))))));
        router = address(uint160(uint(keccak256(abi.encodePacked(uint256(2), blockhash(block.number))))));
        
        balancer = new Balancer(routerEth, router, address(this));

        token1 = new ERC20Mock("Token1", "TKN1");
        token1.mint(address(this), TOKEN_MINT_AMOUNT);
    }
    
    function test_DefaultValues() public {
        assertEq(balancer.disableEth(), false);
        assertEq(address(balancer.routerETH()), routerEth);
        assertEq(address(balancer.router()), router);

    }

    // Owner method tests
    function test_DisableEth() public {
        assertEq(balancer.disableEth(), false);
        balancer.setSwapEth(true);
        assertEq(balancer.disableEth(), true);
    }

    function test_SetSwapEthShouldFailForNonOwner() public {
        vm.startPrank(address(uint160(uint(keccak256(abi.encodePacked(uint256(2), blockhash(block.number)))))));
        vm.expectRevert();
        balancer.setSwapEth(true);
        vm.stopPrank();
    }

    function test_EmergencySaveTokensErc20() public {
        uint256 saveAmount = 10 ether;

        token1.transfer(address(balancer), saveAmount);
        uint256 balancerBalancerBefore = token1.balanceOf(address(balancer));
        assertEq(balancerBalancerBefore, saveAmount);

        uint256 thisBalanceBefore = token1.balanceOf(address(this));
        assertEq(thisBalanceBefore, TOKEN_MINT_AMOUNT - saveAmount);

        balancer.emergencySaveTokens(address(token1), saveAmount);

        uint256 balancerBalancerAfter = token1.balanceOf(address(balancer));
        assertEq(balancerBalancerAfter, 0);

        uint256 thisBalanceAfter = token1.balanceOf(address(this));
        assertEq(thisBalanceAfter, TOKEN_MINT_AMOUNT);
    }

    function test_EmergencySaveTokensNative() public {
        uint256 saveAmount = 10 ether;
        (bool sent, ) = address(balancer).call{value: saveAmount}("");
        assertTrue(sent);

        uint256 balancerBalancerBefore = address(balancer).balance;
        assertEq(balancerBalancerBefore, saveAmount);

        uint256 thisBalanceBefore = address(this).balance;
        assertGt(thisBalanceBefore, 0);

        balancer.emergencySaveTokens(address(0), saveAmount);

        uint256 balancerBalancerAfter = token1.balanceOf(address(balancer));
        assertEq(balancerBalancerAfter, 0);

        uint256 thisBalanceAfter = address(this).balance;
        assertEq(thisBalanceAfter, thisBalanceBefore + saveAmount);
    }

    function test_EmergencySaveTokensShouldNotWorkForNonOwner() public {
        vm.expectRevert();
        vm.prank(randomUser);
        balancer.emergencySaveTokens(address(token1), 1);

    }


    receive() external payable {}
}