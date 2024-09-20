// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// Tapioca
import {IToftVault} from "tap-utils/interfaces/oft/ITOFT.sol";
import {
    ITOFT,
    TOFTInitStruct,
    TOFTModulesInitStruct
} from "tap-utils/interfaces/oft/ITOFT.sol";
import {IMtoftFeeGetter} from "tap-utils/interfaces/oft/IMToftFeeGetter.sol";
import {TOFTVault} from "contracts/tOFT/TOFTVault.sol";
import {BaseTOFT} from "contracts/tOFT/BaseTOFT.sol";
import {mTOFT} from "contracts/tOFT/mTOFT.sol";
import {TOFT} from "contracts/tOFT/TOFT.sol";

// tests
import {OFT_Unit_Shared} from "../../shared/OFT_Unit_Shared.t.sol";

contract TOFT_setters is OFT_Unit_Shared {
    
    modifier whenBalancer {
        mTOFT.SetOwnerStateData memory owState = mTOFT.SetOwnerStateData({
            stargateRouter: address(0),
            feeGetter: IMtoftFeeGetter(address(0)),
            mintCap: 0,
            connectedChain: 0,
            connectedChainState: false,
            balancerStateAddress: address(this),
            balancerState: true
        });
        mToft.setOwnerState(owState);
        _;
    }


    function test_RevertWhen_MTOFTRescueEthIsCalledFromNon_owner() external resetPrank(userA) {
        // it should revert
        vm.expectRevert("Ownable: caller is not the owner");
        mToft.rescueEth(SMALL_AMOUNT, address(this));
    }

    function test_RevertWhen_MTOFTRecueEthIsCalledFromOwnerWithAnInvalidAmount() external {
        // it should revert
        vm.expectRevert(mTOFT.mTOFT_Failed.selector);
        mToft.rescueEth(SMALL_AMOUNT, address(this));
    }

    function test_WhenMTOFTRescueEthIsCalledFromOwnerWithAnAvailableAmount(uint256 amount) external assumeRange(amount, SMALL_AMOUNT, LARGE_AMOUNT) {
        address receiver = makeAddr("receiver");

        vm.deal(address(mToft), amount);
        uint256 balanceBefore = address(receiver).balance;
        mToft.rescueEth(amount, receiver);
        uint256 balanceAfter = address(receiver).balance;

        assertEq(balanceAfter, balanceBefore + amount);
    }

    function test_RevertWhen_MTOFTSetPauseIsCalledFromNon_ownerAndNon_pauser() external resetPrank(userA) {
        // it should revert
        vm.expectRevert(BaseTOFT.TOFT_NotAuthorized.selector);
        mToft.setPause(true);

        // it should revert
        vm.expectRevert(BaseTOFT.TOFT_NotAuthorized.selector);
        mToft.setPause(false);
    }

    function test_WhenMTOFTSetPauseIsCalledFromOwner() external {
        mToft.setPause(true);
        assertTrue(mToft.paused());

        mToft.setPause(false);
        assertFalse(mToft.paused());
    }

    function test_WhenMTOFTSetPauseIsCalledFromPauser() external  {
        // it should pause or unpause
        address rndAddr = makeAddr("rndAddress");
        cluster.setRoleForContract(rndAddr, keccak256("PAUSABLE"), true);

        _resetPrank(rndAddr);

        mToft.setPause(true);
        assertTrue(mToft.paused());

        mToft.setPause(false);
        assertFalse(mToft.paused());
    }

    function test_whenCalledForMTOFT_RevertWhen_WithdrawFeesCalledFromNon_owner() external resetPrank(userA) {
        // it should revert
        vm.expectRevert("Ownable: caller is not the owner");
        mToft.withdrawFees(address(this), SMALL_AMOUNT);
    }

    function test_whenCalledForMTOFT_WhenWithdrawFeesCalledFromOwner(uint256 amount) external assumeRange(amount, SMALL_AMOUNT, LARGE_AMOUNT) {
        TOFTVault vault = TOFTVault(address(mToft.vault()));

        // register fees on vault
        _resetPrank(address(mToft));
        vault.registerFees(amount);

        // add necessary funds
        deal(address(underlyingErc20), address(vault), amount);

        address rndAddr = makeAddr("rndAddress");

        _resetPrank(address(this));
        uint256 balanceBefore = underlyingErc20.balanceOf(address(rndAddr));
        // it should withdraw vault fees
        mToft.withdrawFees(rndAddr, amount);
        uint256 balanceAfter = underlyingErc20.balanceOf(address(rndAddr));

        assertEq(balanceAfter, balanceBefore + amount);
    }

    function test_whenCalledForMTOFT_RevertWhen_ExtractUnderlyingCalledFromNonBalancer() external {
        // it should revert
        vm.expectRevert(mTOFT.mTOFT_BalancerNotAuthorized.selector);
        mToft.extractUnderlying(SMALL_AMOUNT);
    }

    function test_whenCalledForMTOFT_RevertWhen_ExtractUnderlyingCalledWithAmount0() external whenBalancer {
        // it should revert
        vm.expectRevert(BaseTOFT.TOFT_NotValid.selector);
        mToft.extractUnderlying(0);
    }

    function test_whenCalledForMTOFT_WhenExtractUnderlyingIsCalledFromBalancerWithValidAmount(uint256 amount) external whenBalancer assumeRange(amount, SMALL_AMOUNT, LARGE_AMOUNT) {
        TOFTVault vault = TOFTVault(address(mToft.vault()));

        // add necessary funds
        deal(address(underlyingErc20), address(vault), amount);

        uint256 balanceBefore = underlyingErc20.balanceOf(address(this));
        mToft.extractUnderlying(amount);
        uint256 balanceAfter = underlyingErc20.balanceOf(address(this));

        // it should withdraw from vault
        assertEq(balanceAfter, balanceBefore + amount);
    }

    function test_whenCalledForMTOFT_RevertWhen_SetOwnerStateIsCalledFromNonOwner() external  {
        // it should revert
         mTOFT.SetOwnerStateData memory owState = mTOFT.SetOwnerStateData({
            stargateRouter: address(0),
            feeGetter: IMtoftFeeGetter(address(0)),
            mintCap: 0,
            connectedChain: 0,
            connectedChainState: false,
            balancerStateAddress: address(this),
            balancerState: true
        });

        _resetPrank(userA);
        vm.expectRevert("Ownable: caller is not the owner");
        mToft.setOwnerState(owState);
    }

    function test_whenCalledForMTOFT_WhenSetOwnerStateIsCalledFromOwner() external {
        mTOFT.SetOwnerStateData memory owState = mTOFT.SetOwnerStateData({
            stargateRouter: address(this),
            feeGetter: IMtoftFeeGetter(address(this)),
            mintCap: SMALL_AMOUNT,
            connectedChain: 100,
            connectedChainState: true,
            balancerStateAddress: address(this),
            balancerState: true
        });
        mToft.setOwnerState(owState);

        // it should update all different values
        assertEq(address(mToft.feeGetter()), address(this));
        assertEq(mToft.mintCap(), SMALL_AMOUNT);
        assertTrue(mToft.connectedChains(100));
        assertTrue(mToft.balancers(address(this)));
    }

    function test_whenSetOwnerStateIsCalledFromOwner_RevertWhen_MintCapIsSmallerThanSupply(uint256 amount) external assumeRange(amount, SMALL_AMOUNT, LARGE_AMOUNT)  
    {
        // increase TOFT supply my minting
        _wrap(amount);
        
        // it should revert
        mTOFT.SetOwnerStateData memory owState = mTOFT.SetOwnerStateData({
            stargateRouter: address(0),
            feeGetter: IMtoftFeeGetter(address(0)),
            mintCap: 100,
            connectedChain: 0,
            connectedChainState: false,
            balancerStateAddress: address(this),
            balancerState: false
        });
        vm.expectRevert(mTOFT.mTOFT_CapNotValid.selector);
        mToft.setOwnerState(owState);
    }

    function _wrap(uint256 amount) private 
        whenApprovedViaERC20(address(underlyingErc20), address(this), address(pearlmit), type(uint256).max)
        whenApprovedViaPearlmit(
            TOKEN_TYPE_ERC20,
            address(underlyingErc20),
            0,
            address(this),
            address(mToft),
            type(uint200).max,
            uint48(block.timestamp)
        ) 
    {
        deal(address(underlyingErc20), address(this), amount);
        mToft.wrap(address(this), address(this), amount);
        assertTrue(mToft.totalSupply() > 0);
    }


    function test_whenCalledForTOFT_RevertWhen_RescueEthIsCalledFromNon_owner() external resetPrank(userA)  {
        // it should revert
        vm.expectRevert("Ownable: caller is not the owner");
        toft.rescueEth(SMALL_AMOUNT, address(this));
    }

    function test_whenCalledForTOFT_RevertWhen_RecueEthIsCalledFromOwnerWithAnInvalidAmount() external {
        // it should revert
        vm.expectRevert(TOFT.TOFT_Failed.selector);
        toft.rescueEth(SMALL_AMOUNT, address(this));
    }

    function test_whenCalledForTOFT_WhenRescueEthIsCalledFromOwnerWithAnAvailableAmount(uint256 amount) external assumeRange(amount, SMALL_AMOUNT, LARGE_AMOUNT) {
        address receiver = makeAddr("receiver");

        vm.deal(address(toft), amount);
        uint256 balanceBefore = address(receiver).balance;
        toft.rescueEth(amount, receiver);
        uint256 balanceAfter = address(receiver).balance;

        assertEq(balanceAfter, balanceBefore + amount);
    }

    function test_whenCalledForTOFT_RevertWhen_SetPauseIsCalledFromNon_ownerAndNon_pauser() external resetPrank(userA) {
        // it should revert
        vm.expectRevert(BaseTOFT.TOFT_NotAuthorized.selector);
        toft.setPause(true);

        // it should revert
        vm.expectRevert(BaseTOFT.TOFT_NotAuthorized.selector);
        toft.setPause(false);
    }

    function test_whenCalledForTOFT_WhenSetPauseIsCalledFromOwner() external {
        toft.setPause(true);
        assertTrue(toft.paused());

        toft.setPause(false);
        assertFalse(toft.paused());
    }

    function test_whenCalledForTOFT_WhenSetPauseIsCalledFromPauser() external {
        // it should pause or unpause
        address rndAddr = makeAddr("rndAddress");
        cluster.setRoleForContract(rndAddr, keccak256("PAUSABLE"), true);

        _resetPrank(rndAddr);

        toft.setPause(true);
        assertTrue(toft.paused());

        toft.setPause(false);
        assertFalse(toft.paused());
    }
}
