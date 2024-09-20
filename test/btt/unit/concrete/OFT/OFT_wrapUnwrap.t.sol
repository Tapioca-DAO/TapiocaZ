// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// Tapioca
import {TapiocaOmnichainExtExec} from "tap-utils/tapiocaOmnichainEngine/extension/TapiocaOmnichainExtExec.sol";
import {TOFTVault} from "contracts/tOFT/TOFTVault.sol";
import {BaseTOFT} from "contracts/tOFT/BaseTOFT.sol";
import {mTOFT} from "contracts/tOFT/mTOFT.sol";
import {IPearlmit} from "tap-utils/pearlmit/Pearlmit.sol";
import {TOFT} from "contracts/tOFT/TOFT.sol";
import {
    ITOFT,
    TOFTInitStruct,
    TOFTModulesInitStruct
} from "tap-utils/interfaces/oft/ITOFT.sol";

import {IMtoftFeeGetter} from "tap-utils/interfaces/oft/IMToftFeeGetter.sol";

// tests
import {OFT_Unit_Shared} from "../../shared/OFT_Unit_Shared.t.sol";

contract TOFT_wrapUnwrap is OFT_Unit_Shared {
    function test_whenCalledAgainstTOFT_RevertWhen_TOFTWrapCalledForPausedContract() external whenPaused {
        // it should revert
        vm.expectRevert("Pausable: paused");
        toft.wrap(address(this), address(this), SMALL_AMOUNT);
    }

    function test_whenCalledAgainstTOFT_RevertWhen_TOFTWrapCalledFromNonHostChain() external {
        TOFT oft = _createWrongHostToft();

        // it should revert
        vm.expectRevert(TOFT.TOFT_OnlyHostChain.selector);
        oft.wrap(address(this), address(this), SMALL_AMOUNT);
    }

    function test_whenCalledAgainstTOFT_whenCalledAgainstTOFT_WhenTOFTWrapCalledForETH(uint256 amount) 
        external 
        assumeRange(amount, SMALL_AMOUNT, LARGE_AMOUNT)
    {
        // should revert as ETH is not sent with the tx
        vm.expectRevert(TOFT.TOFT_Failed.selector);
        toftEth.wrap(address(this), address(this), amount);


        TOFTVault vault = TOFTVault(address(toftEth.vault()));

        uint256 vaultBalanceBefore = address(vault).balance;
        uint256 toftSupplyBefore = toftEth.totalSupply();
        uint256 receiverBalanceBefore = toftEth.balanceOf(address(this));

        // should not revert
        toftEth.wrap{value: amount}(address(this), address(this), amount);

        uint256 vaultBalanceAfter = address(vault).balance;
        uint256 toftSupplyAfter = toftEth.totalSupply();
        uint256 receiverBalanceAfter = toftEth.balanceOf(address(this));

        // it should deposit ETH amount to the vault
        assertEq(vaultBalanceBefore + amount, vaultBalanceAfter);
        // it should increase supply
        assertEq(toftSupplyBefore + amount, toftSupplyAfter);
        // it should mint OFT to the reicever
        assertEq(receiverBalanceBefore + amount, receiverBalanceAfter);
    }

    function test_whenCalledAgainstTOFT_WhenTOFTWrapCalledForTokenWithTheSameDecimals(uint256 amount)
        external
        assumeRange(amount, SMALL_AMOUNT, LARGE_AMOUNT)
    {

        TOFTVault vault = TOFTVault(address(toft.vault()));

        uint256 vaultBalanceBefore = underlyingErc20.balanceOf(address(vault));
        uint256 toftSupplyBefore = toft.totalSupply();
        uint256 receiverBalanceBefore = toft.balanceOf(address(this));
    
        _wrapOft(amount, address(underlyingErc20), payable(toft));

        uint256 vaultBalanceAfter = underlyingErc20.balanceOf(address(vault));
        uint256 toftSupplyAfter = toft.totalSupply();
        uint256 receiverBalanceAfter = toft.balanceOf(address(this));

        // it should deposit token amount to the vault
        assertEq(vaultBalanceBefore + amount, vaultBalanceAfter);
        // it should mint OFT to the reicever
        assertEq(receiverBalanceBefore + amount, receiverBalanceAfter);
        // it should increase supply
        assertEq(toftSupplyBefore + amount, toftSupplyAfter);
    }

    function test_whenCalledAgainstTOFT_WhenTOFTWrapCalledForTokenWithTheDifferentDecimals(uint256 amount)
        external
        assumeRange(amount, LOW_DECIMALS_SMALL_AMOUNT, LOW_DECIMALS_LARGE_AMOUNT)
    {
        TOFTVault vault = TOFTVault(address(toftLowDecimals.vault()));

        uint256 vaultBalanceBefore = underlyingLowDecimalsErc20.balanceOf(address(vault));
        uint256 toftSupplyBefore = toftLowDecimals.totalSupply();
        uint256 receiverBalanceBefore = toftLowDecimals.balanceOf(address(this));
        uint256 underlyingSupplyBefore = underlyingLowDecimalsErc20.totalSupply();

        _wrapOft(amount, address(underlyingLowDecimalsErc20), payable(toftLowDecimals));

        uint256 vaultBalanceAfter = underlyingLowDecimalsErc20.balanceOf(address(vault));
        uint256 toftSupplyAfter = toftLowDecimals.totalSupply();
        uint256 receiverBalanceAfter = toftLowDecimals.balanceOf(address(this));
        uint256 underlyingSupplyAfter = underlyingLowDecimalsErc20.totalSupply();

        // it should deposit token amount to the vault
        assertEq(vaultBalanceBefore + amount, vaultBalanceAfter);
        // it should mint OFT to the reicever
        assertEq(receiverBalanceBefore + amount, receiverBalanceAfter);
        // it should increase supply
        assertEq(toftSupplyBefore + amount, toftSupplyAfter);
        // it should increase supply for underlying erc20
        assertEq(underlyingSupplyBefore + amount, underlyingSupplyAfter);

    }

    function test_whenCalledAgainstTOFT_RevertWhen_TOFTUnwrapCalledFromNonHostChain() external {
        TOFT oft = _createWrongHostToft();

        // it should revert
        vm.expectRevert(TOFT.TOFT_OnlyHostChain.selector);
        oft.unwrap(address(this), SMALL_AMOUNT);
    }

    function test_whenCalledAgainstTOFT_RevertWhen_TOFTUnwrapCalledWithInvalidAmount() external {
        // it should revert
        vm.expectRevert("ERC20: burn amount exceeds balance");
        toft.unwrap(address(this), LARGE_AMOUNT);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        toftLowDecimals.unwrap(address(this), LARGE_AMOUNT);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        toftEth.unwrap(address(this), LARGE_AMOUNT);
    }


    function test_whenCalledAgainstTOFT_WhenTOFTUnwrapCalledForETH_WithoutFees(uint256 amount, uint256 unwrapAmount) 
        external 
        assumeRange(amount, SMALL_AMOUNT, LARGE_AMOUNT)
    {
        unwrapAmount = bound(unwrapAmount, SMALL_AMOUNT, amount);

        // wrap 
        toftEth.wrap{value: amount}(address(this), address(this), amount);

        TOFTVault vault = TOFTVault(address(toftEth.vault()));
        uint256 vaultBalanceBefore = address(vault).balance;
        uint256 toftSupplyBefore = toftEth.totalSupply();
        uint256 receiverBalanceBefore = toftEth.balanceOf(address(this));


        toftEth.unwrap(address(this), unwrapAmount);

        uint256 vaultBalanceAfter = address(vault).balance;
        uint256 toftSupplyAfter = toftEth.totalSupply();
        uint256 receiverBalanceAfter = toftEth.balanceOf(address(this));

        // it should withdraw from vault
        assertEq(vaultBalanceBefore - unwrapAmount, vaultBalanceAfter);
        // it should decrease supply
        assertEq(toftSupplyBefore - unwrapAmount, toftSupplyAfter);
        assertEq(receiverBalanceBefore - unwrapAmount, receiverBalanceAfter);
    }

    function test_whenCalledAgainstTOFT_WhenTOFTUnwrapCalledForToken(uint256 amount, uint256 unwrapAmount) 
        external 
        assumeRange(amount, SMALL_AMOUNT, LARGE_AMOUNT)
    {
        unwrapAmount = bound(unwrapAmount, SMALL_AMOUNT, amount);

        // wrap 
        _wrapOft(amount, address(underlyingErc20), payable(toft));

        TOFTVault vault = TOFTVault(address(toft.vault()));
        uint256 vaultBalanceBefore = underlyingErc20.balanceOf(address(vault));
        uint256 toftSupplyBefore = toft.totalSupply();
        uint256 receiverBalanceBefore = toft.balanceOf(address(this));


        toft.unwrap(address(this), unwrapAmount);

        uint256 vaultBalanceAfter = underlyingErc20.balanceOf(address(vault));
        uint256 toftSupplyAfter = toft.totalSupply();
        uint256 receiverBalanceAfter = toft.balanceOf(address(this));

        // it should withdraw from vault
        assertEq(vaultBalanceBefore - unwrapAmount, vaultBalanceAfter);
        // it should decrease supply
        assertEq(toftSupplyBefore - unwrapAmount, toftSupplyAfter);
        assertEq(receiverBalanceBefore - unwrapAmount, receiverBalanceAfter);
    }


    function test_whenCalledAgainstMTOFT_RevertWhen_MTOFTWrapCalledForPausedContract() external whenPaused {
        // it should revert
        vm.expectRevert("Pausable: paused");
        toft.wrap(address(this), address(this), SMALL_AMOUNT);
    }

    function test_whenCalledAgainstMTOFT_RevertWhen_MTOFTWrapCalledFromNonHostChain() external {
        mTOFT oft = _createWrongHostMToft();

        // it should revert
        vm.expectRevert(mTOFT.mTOFT_NotHost.selector);
        oft.wrap(address(this), address(this), SMALL_AMOUNT);
    }


    function test_whenCalledAgainstMTOFT_WhenMTOFTWrapCalledForETH(uint256 amount)
        external
        assumeRange(amount, SMALL_AMOUNT, LARGE_AMOUNT)
    {
        // should revert as ETH is not sent with the tx
        vm.expectRevert(mTOFT.mTOFT_Failed.selector);
        mToftEth.wrap(address(this), address(this), amount);


        TOFTVault vault = TOFTVault(address(mToftEth.vault()));

        uint256 vaultBalanceBefore = address(vault).balance;
        uint256 toftSupplyBefore = mToftEth.totalSupply();
        uint256 receiverBalanceBefore = mToftEth.balanceOf(address(this));

        // should not revert
        mToftEth.wrap{value: amount}(address(this), address(this), amount);

        uint256 vaultBalanceAfter = address(vault).balance;
        uint256 toftSupplyAfter = mToftEth.totalSupply();
        uint256 receiverBalanceAfter = mToftEth.balanceOf(address(this));

        // it should deposit ETH amount to the vault
        assertEq(vaultBalanceBefore + amount, vaultBalanceAfter);
        // it should increase supply
        assertEq(toftSupplyBefore + amount, toftSupplyAfter);
        // it should mint OFT to the reicever
        assertEq(receiverBalanceBefore + amount, receiverBalanceAfter);
    }

    function test_whenCalledAgainstMTOFT_WhenMTOFTWrapCalledForTokenWithTheSameDecimals(uint256 amount)
        external
        assumeRange(amount, SMALL_AMOUNT, LARGE_AMOUNT)
    {
        TOFTVault vault = TOFTVault(address(mToft.vault()));

        uint256 vaultBalanceBefore = underlyingErc20.balanceOf(address(vault));
        uint256 toftSupplyBefore = mToft.totalSupply();
        uint256 receiverBalanceBefore = mToft.balanceOf(address(this));
    
        _wrapOft(amount, address(underlyingErc20), payable(mToft));

        uint256 vaultBalanceAfter = underlyingErc20.balanceOf(address(vault));
        uint256 toftSupplyAfter = mToft.totalSupply();
        uint256 receiverBalanceAfter = mToft.balanceOf(address(this));

        // it should deposit token amount to the vault
        assertEq(vaultBalanceBefore + amount, vaultBalanceAfter);
        // it should mint OFT to the reicever
        assertEq(receiverBalanceBefore + amount, receiverBalanceAfter);
        // it should increase supply
        assertEq(toftSupplyBefore + amount, toftSupplyAfter);
    }

    function test_whenCalledAgainstMTOFT_WhenMTOFTWrapCalledForTokenWithTheDifferentDecimals(uint256 amount)
        external
        assumeRange(amount, LOW_DECIMALS_SMALL_AMOUNT, LOW_DECIMALS_LARGE_AMOUNT)
    {
        TOFTVault vault = TOFTVault(address(mToftLowDecimals.vault()));

        uint256 vaultBalanceBefore = underlyingLowDecimalsErc20.balanceOf(address(vault));
        uint256 toftSupplyBefore = mToftLowDecimals.totalSupply();
        uint256 receiverBalanceBefore = mToftLowDecimals.balanceOf(address(this));
        uint256 underlyingSupplyBefore = underlyingLowDecimalsErc20.totalSupply();

        _wrapOft(amount, address(underlyingLowDecimalsErc20), payable(mToftLowDecimals));

        uint256 vaultBalanceAfter = underlyingLowDecimalsErc20.balanceOf(address(vault));
        uint256 toftSupplyAfter = mToftLowDecimals.totalSupply();
        uint256 receiverBalanceAfter = mToftLowDecimals.balanceOf(address(this));
        uint256 underlyingSupplyAfter = underlyingLowDecimalsErc20.totalSupply();

        // it should deposit token amount to the vault
        assertEq(vaultBalanceBefore + amount, vaultBalanceAfter);
        // it should mint OFT to the reicever
        assertEq(receiverBalanceBefore + amount, receiverBalanceAfter);
        // it should increase supply
        assertEq(toftSupplyBefore + amount, toftSupplyAfter);
        // it should increase supply for underlying erc20
        assertEq(underlyingSupplyBefore + amount, underlyingSupplyAfter);
    }


    function test_whenCalledAgainstMTOFT_RevertWhen_MTOFTUnwrapCalledFromNonHostChain()
        external
    {
        mTOFT oft = _createWrongHostMToft();

        // it should revert
        vm.expectRevert(mTOFT.mTOFT_NotHost.selector);
        oft.unwrap(address(this), SMALL_AMOUNT);
    }

    function test_whenCalledAgainstMTOFT_RevertWhen_MTOFTUnwrapCalledWithInvalidAmount()
        external
    {
        vm.expectRevert("ERC20: burn amount exceeds balance");
        mToft.unwrap(address(this), LARGE_AMOUNT);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        mToftLowDecimals.unwrap(address(this), LARGE_AMOUNT);

        vm.expectRevert("ERC20: burn amount exceeds balance");
        mToftEth.unwrap(address(this), LARGE_AMOUNT);
    }

    function test_whenCalledAgainstMTOFT_WhenMTOFTUnwrapCalledForETH_WithoutFees(uint256 amount, uint256 unwrapAmount) 
        external 
        assumeRange(amount, SMALL_AMOUNT, LARGE_AMOUNT)
    {
        unwrapAmount = bound(unwrapAmount, SMALL_AMOUNT, amount);

        // wrap 
        mToftEth.wrap{value: amount}(address(this), address(this), amount);

        TOFTVault vault = TOFTVault(address(mToftEth.vault()));
        uint256 vaultBalanceBefore = address(vault).balance;
        uint256 toftSupplyBefore = mToftEth.totalSupply();
        uint256 receiverBalanceBefore = mToftEth.balanceOf(address(this));


        mToftEth.unwrap(address(this), unwrapAmount);

        uint256 vaultBalanceAfter = address(vault).balance;
        uint256 toftSupplyAfter = mToftEth.totalSupply();
        uint256 receiverBalanceAfter = mToftEth.balanceOf(address(this));

        // it should withdraw from vault
        assertEq(vaultBalanceBefore - unwrapAmount, vaultBalanceAfter);
        // it should decrease supply
        assertEq(toftSupplyBefore - unwrapAmount, toftSupplyAfter);
        assertEq(receiverBalanceBefore - unwrapAmount, receiverBalanceAfter);
    }

    function test_whenCalledAgainstMTOFT_WhenMTOFTUnwrapCalledForETH_WithFees(uint256 amount, uint256 unwrapAmount) 
        external 
        assumeRange(amount, SMALL_AMOUNT, LARGE_AMOUNT)
    {
        unwrapAmount = bound(unwrapAmount, SMALL_AMOUNT, amount);

        {
            mTOFT.SetOwnerStateData memory owState = mTOFT.SetOwnerStateData({
                stargateRouter: address(0),
                feeGetter: IMtoftFeeGetter(address(oftFeeGetter)),
                mintCap: 0,
                connectedChain: 0,
                connectedChainState: false,
                balancerStateAddress: address(0),
                balancerState: false
            });
            mToftEth.setOwnerState(owState);
        }

        // wrap 
        mToftEth.wrap{value: amount}(address(this), address(this), amount);

        TOFTVault vault = TOFTVault(address(mToftEth.vault()));
        uint256 vaultBalanceBefore = address(vault).balance;
        uint256 toftSupplyBefore = mToftEth.totalSupply();
        uint256 receiverBalanceBefore = mToftEth.balanceOf(address(this));

        uint256 unwrapped = mToftEth.unwrap(address(this), unwrapAmount);

        uint256 vaultBalanceAfter = address(vault).balance;
        uint256 toftSupplyAfter = mToftEth.totalSupply();
        uint256 receiverBalanceAfter = mToftEth.balanceOf(address(this));

        // it should withdraw from vault
        assertEq(vaultBalanceBefore - unwrapped, vaultBalanceAfter);
        // it should decrease supply
        assertEq(toftSupplyBefore - unwrapAmount, toftSupplyAfter);
        assertEq(receiverBalanceBefore - unwrapAmount, receiverBalanceAfter);

        // it should check fees
        {
            uint256 feeAmount = vault.viewFees();
            assertEq(feeAmount, unwrapAmount - unwrapped);
        }
    }

    function test_whenCalledAgainstMTOFT_WhenMTOFTUnwrapCalledForToken(uint256 amount, uint256 unwrapAmount) 
        external 
        assumeRange(amount, SMALL_AMOUNT, LARGE_AMOUNT)
    {
        unwrapAmount = bound(unwrapAmount, SMALL_AMOUNT, amount);

        // wrap 
        _wrapOft(amount, address(underlyingErc20), payable(mToft));

        TOFTVault vault = TOFTVault(address(mToft.vault()));
        uint256 vaultBalanceBefore = underlyingErc20.balanceOf(address(vault));
        uint256 toftSupplyBefore = mToft.totalSupply();
        uint256 receiverBalanceBefore = mToft.balanceOf(address(this));


        mToft.unwrap(address(this), unwrapAmount);

        uint256 vaultBalanceAfter = underlyingErc20.balanceOf(address(vault));
        uint256 toftSupplyAfter = mToft.totalSupply();
        uint256 receiverBalanceAfter = mToft.balanceOf(address(this));

        // it should withdraw from vault
        assertEq(vaultBalanceBefore - unwrapAmount, vaultBalanceAfter);
        // it should decrease supply
        assertEq(toftSupplyBefore - unwrapAmount, toftSupplyAfter);
        assertEq(receiverBalanceBefore - unwrapAmount, receiverBalanceAfter);
    }


    
    function _createWrongHostToft() private returns (TOFT oft) {
        TOFTVault _vault = new TOFTVault(address(underlyingErc20));
        TapiocaOmnichainExtExec _extExec = new TapiocaOmnichainExtExec();
        TOFTInitStruct memory wrongInitStruct = TOFTInitStruct({
            name: "Wrong Host TOFT",
            symbol: "WRONG",
            endpoint: address(endpoints[aEid]),
            delegate: address(this),
            yieldBox: address(yieldBox),
            cluster: address(cluster),
            erc20: address(underlyingErc20),
            vault: address(_vault),
            hostEid: bEid,
            extExec: address(_extExec),
            pearlmit: IPearlmit(address(pearlmit))
        });
        TOFTModulesInitStruct memory wrongModuleStruct = _createOftModuleStruct(address(toftSender), address(toftReceiver), address(toftMarketReceiverModule), address(toftOptionsReceiverModule), address(toftGenericReceiverModule));

        oft = new TOFT(wrongInitStruct, wrongModuleStruct);
    }

    function _createWrongHostMToft() private returns (mTOFT oft) {
        TOFTVault _vault = new TOFTVault(address(underlyingErc20));
        TapiocaOmnichainExtExec _extExec = new TapiocaOmnichainExtExec();
        TOFTInitStruct memory wrongInitStruct = TOFTInitStruct({
            name: "Wrong Host TOFT",
            symbol: "WRONG",
            endpoint: address(endpoints[aEid]),
            delegate: address(this),
            yieldBox: address(yieldBox),
            cluster: address(cluster),
            erc20: address(underlyingErc20),
            vault: address(_vault),
            hostEid: bEid,
            extExec: address(_extExec),
            pearlmit: IPearlmit(address(pearlmit))
        });
        TOFTModulesInitStruct memory wrongModuleStruct = _createOftModuleStruct(address(mtoftSender), address(mtoftReceiver), address(mtoftMarketReceiverModule), address(mtoftOptionsReceiverModule), address(mtoftGenericReceiverModule));
        
        oft = new mTOFT(wrongInitStruct, wrongModuleStruct, address(this));
    }
}
