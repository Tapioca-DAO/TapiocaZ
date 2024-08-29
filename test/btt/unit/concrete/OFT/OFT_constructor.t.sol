// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// Tapioca
import {IToftVault} from "tap-utils/interfaces/oft/ITOFT.sol";
import {
    ITOFT,
    TOFTInitStruct,
    TOFTModulesInitStruct
} from "tap-utils/interfaces/oft/ITOFT.sol";
import {TOFTVault} from "contracts/tOFT/TOFTVault.sol";
import {BaseTOFT} from "contracts/tOFT/BaseTOFT.sol";
import {mTOFT} from "contracts/tOFT/mTOFT.sol";
import {TOFT} from "contracts/tOFT/TOFT.sol";

// tests
import {OFT_Unit_Shared} from "../../shared/OFT_Unit_Shared.t.sol";

contract OFT_constructor is OFT_Unit_Shared{

    function test_whenTOFTIsCreated_WhenTOFTCreatedWithTheRightParameters() external {
        // it should set the sender module
        assertFalse(address(toftSender) == address(0));

        // it should set the receiver module
        assertFalse(address(toftReceiver) == address(0));

        // it should set the market receiver module
        assertFalse(address(toftMarketReceiverModule) == address(0));

        // it should set the options receiver module
        assertFalse(address(toftOptionsReceiverModule) == address(0));

        // it should set the generic receiver module
        assertFalse(address(toftGenericReceiverModule) == address(0));

        // it should claim vault ownership
        IToftVault toftVault = toft.vault();
        assertEq(toftVault.owner(), address(toft));

        // it should set the owner
        assertEq(toft.owner(), address(this));

        // it should set the host endpoint
        assertEq(toft.hostEid(), aEid);

        // it should have the right underlying token
        assertEq(toft.erc20(), address(underlyingErc20));

        // it should return 18 decimals
        assertEq(toft.decimals(), 18);

        // it should set YieldBox
        assertEq(address(toft.yieldBox()), address(yieldBox));
    }


    function test_whenTOFTCreatedWithWrongParameters_RevertWhen_WhenEmptyAddressIsUsedForTOFT() external {
        TOFTInitStruct memory initData = _createOftInitStruct(address(underlyingErc20), aEid);

        // it should revert for sender module
        TOFTModulesInitStruct memory modulesData = _createOftModuleStruct(address(0), address(toftReceiver), address(toftMarketReceiverModule), address(toftOptionsReceiverModule), address(toftGenericReceiverModule));
        vm.expectRevert(BaseTOFT.TOFT_NotValid.selector);
        TOFT oft = new TOFT(initData, modulesData);

        // it should revert for receiver module
        modulesData = _createOftModuleStruct(address(toftSender), address(0), address(toftMarketReceiverModule), address(toftOptionsReceiverModule), address(toftGenericReceiverModule));
        vm.expectRevert(BaseTOFT.TOFT_NotValid.selector);
        oft = new TOFT(initData, modulesData);

        // it should revert for market receiver module
        modulesData = _createOftModuleStruct(address(toftSender), address(toftReceiver), address(0), address(toftOptionsReceiverModule), address(toftGenericReceiverModule));
        vm.expectRevert(BaseTOFT.TOFT_NotValid.selector);
        oft = new TOFT(initData, modulesData);

        // it should revert for options receiver module
        modulesData = _createOftModuleStruct(address(toftSender), address(toftReceiver), address(toftMarketReceiverModule), address(0), address(toftGenericReceiverModule));
        vm.expectRevert(BaseTOFT.TOFT_NotValid.selector);
        oft = new TOFT(initData, modulesData);

        // it should revert for generic receiver module
        modulesData = _createOftModuleStruct(address(toftSender), address(toftReceiver), address(toftMarketReceiverModule), address(toftOptionsReceiverModule), address(0));
        vm.expectRevert(BaseTOFT.TOFT_NotValid.selector);
        oft = new TOFT(initData, modulesData);
    }

    function test_whenTOFTCreatedWithWrongParameters_RevertWhen_TOFTVaultTokenIsDifferent()
        external
    {
        TOFTInitStruct memory initData = _createOftInitStruct(address(underlyingErc20), aEid);
        TOFTModulesInitStruct memory modulesData = _createOftModuleStruct(address(toftSender), address(toftReceiver), address(toftMarketReceiverModule), address(toftOptionsReceiverModule), address(toftGenericReceiverModule));

        address randomToken = address(_createToken("randomToken", 18));

        TOFTVault _wrongVault = new TOFTVault(randomToken);
        initData.vault = address(_wrongVault);

        // it should revert
        vm.expectRevert(BaseTOFT.TOFT_VaultWrongERC20.selector);
        TOFT oft = new TOFT(initData, modulesData);
    }


    function test_WhenMTOFTCreatedWithTheRightParameters() external {
        // it should set the sender module
        assertFalse(address(mtoftSender) == address(0));

        // it should set the receiver module
        assertFalse(address(mtoftReceiver) == address(0));

        // it should set the market receiver module
        assertFalse(address(mtoftMarketReceiverModule) == address(0));

        // it should set the options receiver module
        assertFalse(address(mtoftOptionsReceiverModule) == address(0));

        // it should set the generic receiver module
        assertFalse(address(mtoftGenericReceiverModule) == address(0));

        // it should claim vault ownership
        IToftVault mtoftVault = mToft.vault();
        assertEq(mtoftVault.owner(), address(mToft));

        // it should set the owner
        assertEq(mToft.owner(), address(this));

        // it should set the host endpoint
        assertEq(mToft.hostEid(), aEid);

        // it should have the right underlying token
        assertEq(mToft.erc20(), address(underlyingErc20));

        // it should return 18 decimals
        assertEq(mToft.decimals(), 18);

        // it should set YieldBox
        assertEq(address(mToft.yieldBox()), address(yieldBox));

        // it should set Stargate router


        // it should set a default mint cap
        assertEq(mToft.mintCap(), DEFAULT_MINT_CAP);
    }


    function test_whenMTOFTCreatedWithWrongParameters_RevertWhen_WhenEmptyAddressIsUsedForMTOFT() external {
        TOFTInitStruct memory initData = _createOftInitStruct(address(underlyingErc20), aEid);

        // it should revert for sender module
        TOFTModulesInitStruct memory modulesData = _createOftModuleStruct(address(0), address(mtoftReceiver), address(mtoftMarketReceiverModule), address(mtoftOptionsReceiverModule), address(mtoftGenericReceiverModule));
        vm.expectRevert(BaseTOFT.TOFT_NotValid.selector);
        mTOFT oft = new mTOFT(initData, modulesData, address(this));

        // it should revert for receiver module
        modulesData = _createOftModuleStruct(address(mtoftSender), address(0), address(mtoftMarketReceiverModule), address(mtoftOptionsReceiverModule), address(mtoftGenericReceiverModule));
        vm.expectRevert(BaseTOFT.TOFT_NotValid.selector);
        oft = new mTOFT(initData, modulesData, address(this));

        // it should revert for market receiver module
        modulesData = _createOftModuleStruct(address(mtoftSender), address(mtoftReceiver), address(0), address(mtoftOptionsReceiverModule), address(mtoftGenericReceiverModule));
        vm.expectRevert(BaseTOFT.TOFT_NotValid.selector);
        oft = new mTOFT(initData, modulesData, address(this));

        // it should revert for options receiver module
        modulesData = _createOftModuleStruct(address(mtoftSender), address(mtoftReceiver), address(mtoftMarketReceiverModule), address(0), address(mtoftGenericReceiverModule));
        vm.expectRevert(BaseTOFT.TOFT_NotValid.selector);
        oft = new mTOFT(initData, modulesData, address(this));

        // it should revert for generic receiver module
        modulesData = _createOftModuleStruct(address(mtoftSender), address(mtoftReceiver), address(mtoftMarketReceiverModule), address(mtoftOptionsReceiverModule), address(0));
        vm.expectRevert(BaseTOFT.TOFT_NotValid.selector);
        oft = new mTOFT(initData, modulesData, address(this));
    }

    function test_whenMTOFTCreatedWithWrongParameters_RevertWhen_MTOFTVaultTokenIsDifferent()
        external
    {
        TOFTInitStruct memory initData = _createOftInitStruct(address(underlyingErc20), aEid);
        TOFTModulesInitStruct memory modulesData = _createOftModuleStruct(address(mtoftSender), address(mtoftReceiver), address(mtoftMarketReceiverModule), address(mtoftOptionsReceiverModule), address(mtoftGenericReceiverModule));

        address randomToken = address(_createToken("randomToken", 18));

        TOFTVault _wrongVault = new TOFTVault(randomToken);
        initData.vault = address(_wrongVault);

        // it should revert
        vm.expectRevert(BaseTOFT.TOFT_VaultWrongERC20.selector);
        mTOFT oft = new mTOFT(initData, modulesData, address(this));
    }
}
