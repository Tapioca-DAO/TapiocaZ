// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// external
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// contracts
import {IPearlmit, Pearlmit} from "tap-utils/pearlmit/Pearlmit.sol";
import {Cluster} from "tap-utils/Cluster/Cluster.sol";
import {
    ITOFT,
    TOFTInitStruct,
    TOFTModulesInitStruct
} from "tap-utils/interfaces/oft/ITOFT.sol";
import {YieldBox} from "yieldbox/YieldBox.sol";

import {TapiocaOmnichainExtExec} from "tap-utils/tapiocaOmnichainEngine/extension/TapiocaOmnichainExtExec.sol";
import {TOFTGenericReceiverModule} from "contracts/tOFT/modules/TOFTGenericReceiverModule.sol";
import {TOFTOptionsReceiverModule} from "contracts/tOFT/modules/TOFTOptionsReceiverModule.sol";
import {TOFTMarketReceiverModule} from "contracts/tOFT/modules/TOFTMarketReceiverModule.sol";
import {mTOFTReceiver} from "contracts/tOFT/modules/mTOFTReceiver.sol";
import {TOFTReceiver} from "contracts/tOFT/modules/TOFTReceiver.sol";
import {TOFTSender} from "contracts/tOFT/modules/TOFTSender.sol";
import {TOFTVault} from "contracts/tOFT/TOFTVault.sol";
import {mTOFT} from "contracts/tOFT/mTOFT.sol";
import {TOFT} from "contracts/tOFT/TOFT.sol";

// tests
import {FeeGetterMock_test} from "./mocks/FeeGetterMock_test.sol";
import {ERC20Mock_test} from "./mocks/ERC20Mock_test.sol";
import {TestHelper} from "../LZSetup/TestHelper.sol";
import {Events} from "./utils/Events.sol";
import {Utils} from "./utils/Utils.sol";
import {Types} from "./utils/Types.sol";

abstract contract Base_Test is TestHelper, Utils, Types, Events {
    // ************ //
    // *** VARS *** //
    // ************ //
    // endpoints
    uint32 public aEid = 1;
    uint32 public bEid = 2;

    // users
    address public userA;
    address public userB;
    uint256 public initialBalance = LARGE_AMOUNT;

    // common general storage
    YieldBox yieldBox;
    Pearlmit pearlmit;
    Cluster cluster;

    // tokens
    ERC20Mock_test underlyingErc20; 
    ERC20Mock_test underlyingLowDecimalsErc20; 
    TOFT toft;
    TOFT toftLowDecimals;
    TOFT toftEth;
    mTOFT mToft;
    mTOFT mToftLowDecimals;
    mTOFT mToftEth;

    FeeGetterMock_test oftFeeGetter;

    // toft data
    TOFTSender toftSender;
    TOFTReceiver toftReceiver;
    TOFTMarketReceiverModule toftMarketReceiverModule;
    TOFTOptionsReceiverModule toftOptionsReceiverModule;
    TOFTGenericReceiverModule toftGenericReceiverModule;

    TOFTSender toftSenderEth;
    TOFTReceiver toftReceiverEth;
    TOFTMarketReceiverModule toftMarketReceiverModuleEth;
    TOFTOptionsReceiverModule toftOptionsReceiverModuleEth;
    TOFTGenericReceiverModule toftGenericReceiverModuleEth;

    // mToft data
    TOFTSender mtoftSender;
    TOFTReceiver mtoftReceiver;
    TOFTMarketReceiverModule mtoftMarketReceiverModule;
    TOFTOptionsReceiverModule mtoftOptionsReceiverModule;
    TOFTGenericReceiverModule mtoftGenericReceiverModule;

    TOFTSender mtoftSenderEth;
    TOFTReceiver mtoftReceiverEth;
    TOFTMarketReceiverModule mtoftMarketReceiverModuleEth;
    TOFTOptionsReceiverModule mtoftOptionsReceiverModuleEth;
    TOFTGenericReceiverModule mtoftGenericReceiverModuleEth;

    // ************* //
    // *** SETUP *** //
    // ************* //
    function setUp() public virtual override {
        // ***  *** //
        userA = _createUser(USER_A_PKEY, "User A");
        userB = _createUser(USER_B_PKEY, "User B"); 

        // setup 3 LZ endpoints
        setUpEndpoints(3, LibraryType.UltraLightNode);

        oftFeeGetter = new FeeGetterMock_test();
        vm.label(address(oftFeeGetter), "oftFeeGetter");

        underlyingErc20 = _createToken("underlyingErc20", 18);
        underlyingLowDecimalsErc20 = _createToken("underlyingLowDecimalsErc20", 6);

        // create real Cluster
        cluster = _createCluster(address(this));
        // create real Pearlmit
        pearlmit = _createPearlmit(address(this));
        // create real YieldBox
        yieldBox = _createYieldBox(address(this), pearlmit);

        // creat TOFT underlyingErc20
        TOFTInitStruct memory toftInitStruct = _createOftInitStruct(address(underlyingErc20), aEid);
        toftSender = new TOFTSender(toftInitStruct);
        vm.label(address(toftSender), "toftSender");
        toftReceiver = new TOFTReceiver(toftInitStruct);
        vm.label(address(toftReceiver), "toftReceiver");
        toftMarketReceiverModule = new TOFTMarketReceiverModule(toftInitStruct);
        vm.label(address(toftMarketReceiverModule), "toftMarketReceiverModule");
        toftOptionsReceiverModule = new TOFTOptionsReceiverModule(toftInitStruct);
        vm.label(address(toftOptionsReceiverModule), "toftOptionsReceiverModule");
        toftGenericReceiverModule = new TOFTGenericReceiverModule(toftInitStruct);
        vm.label(address(toftGenericReceiverModule), "toftGenericReceiverModule");

        // creat TOFT ETH
        TOFTInitStruct memory toftInitStructEth = _createOftInitStruct(address(0), aEid);
        toftSenderEth = new TOFTSender(toftInitStructEth);
        vm.label(address(toftSenderEth), "toftSenderEth");
        toftReceiverEth = new TOFTReceiver(toftInitStructEth);
        vm.label(address(toftReceiverEth), "toftReceiverEth");
        toftMarketReceiverModuleEth = new TOFTMarketReceiverModule(toftInitStructEth);
        vm.label(address(toftMarketReceiverModuleEth), "toftMarketReceiverModuleEth");
        toftOptionsReceiverModuleEth = new TOFTOptionsReceiverModule(toftInitStructEth);
        vm.label(address(toftOptionsReceiverModuleEth), "toftOptionsReceiverModuleEth");
        toftGenericReceiverModuleEth = new TOFTGenericReceiverModule(toftInitStructEth);
        vm.label(address(toftGenericReceiverModuleEth), "toftGenericReceiverModuleEth");

        // creat TOFT underlyingLowDecimalsErc20
        TOFTInitStruct memory toftInitStructLowDecimals = _createOftInitStruct(address(underlyingLowDecimalsErc20), aEid);
        TOFTSender toftSenderLowDecimals = new TOFTSender(toftInitStructLowDecimals);
        vm.label(address(toftSenderLowDecimals), "toftSenderLowDecimals");
        TOFTReceiver toftReceiverLowDecimals = new TOFTReceiver(toftInitStructLowDecimals);
        vm.label(address(toftReceiverLowDecimals), "toftReceiverLowDecimals");
        TOFTMarketReceiverModule toftMarketReceiverModuleLowDecimals = new TOFTMarketReceiverModule(toftInitStructLowDecimals);
        vm.label(address(toftMarketReceiverModuleLowDecimals), "toftMarketReceiverModuleLowDecimals");
        TOFTOptionsReceiverModule toftOptionsReceiverModuleLowDecimals = new TOFTOptionsReceiverModule(toftInitStructLowDecimals);
        vm.label(address(toftOptionsReceiverModuleLowDecimals), "toftOptionsReceiverModuleLowDecimals");
        TOFTGenericReceiverModule toftGenericReceiverModuleLowDecimals = new TOFTGenericReceiverModule(toftInitStructLowDecimals);
        vm.label(address(toftGenericReceiverModuleLowDecimals), "toftGenericReceiverModuleLowDecimals");

        // creat mTOFT underlyingErc20
        TOFTInitStruct memory mToftInitStruct = _createOftInitStruct(address(underlyingErc20), aEid);
        mtoftSender = new TOFTSender(mToftInitStruct);
        vm.label(address(mtoftSender), "mtoftSender");
        mtoftReceiver = new TOFTReceiver(mToftInitStruct);
        vm.label(address(mtoftReceiver), "mtoftReceiver");
        mtoftMarketReceiverModule = new TOFTMarketReceiverModule(mToftInitStruct);
        vm.label(address(mtoftMarketReceiverModule), "mtoftMarketReceiverModule");
        mtoftOptionsReceiverModule = new TOFTOptionsReceiverModule(mToftInitStruct);
        vm.label(address(mtoftOptionsReceiverModule), "mtoftOptionsReceiverModule");
        mtoftGenericReceiverModule = new TOFTGenericReceiverModule(mToftInitStruct);
        vm.label(address(mtoftGenericReceiverModule), "mtoftGenericReceiverModule");

        // creat mTOFT ETH
        TOFTInitStruct memory mToftInitStructEth = _createOftInitStruct(address(0), aEid);
        mtoftSenderEth = new TOFTSender(mToftInitStructEth);
        vm.label(address(mtoftSenderEth), "mtoftSenderEth");
        mtoftReceiverEth = new TOFTReceiver(mToftInitStructEth);
        vm.label(address(mtoftReceiverEth), "mtoftReceiverEth");
        mtoftMarketReceiverModuleEth = new TOFTMarketReceiverModule(mToftInitStructEth);
        vm.label(address(mtoftMarketReceiverModuleEth), "mtoftMarketReceiverModuleEth");
        mtoftOptionsReceiverModuleEth = new TOFTOptionsReceiverModule(mToftInitStructEth);
        vm.label(address(mtoftOptionsReceiverModuleEth), "mtoftOptionsReceiverModuleEth");
        mtoftGenericReceiverModuleEth = new TOFTGenericReceiverModule(mToftInitStructEth);
        vm.label(address(mtoftGenericReceiverModuleEth), "mtoftGenericReceiverModuleEth");

        // creat mTOFT underlyingLowDecimalsErc20
        TOFTInitStruct memory mtoftInitStructLowDecimals = _createOftInitStruct(address(underlyingLowDecimalsErc20), aEid);
        TOFTSender mtoftSenderLowDecimals = new TOFTSender(mtoftInitStructLowDecimals);
        vm.label(address(mtoftSenderLowDecimals), "mtoftSenderLowDecimals");
        TOFTReceiver mtoftReceiverLowDecimals = new TOFTReceiver(mtoftInitStructLowDecimals);
        vm.label(address(mtoftReceiverLowDecimals), "mtoftReceiverLowDecimals");
        TOFTMarketReceiverModule mtoftMarketReceiverModuleLowDecimals = new TOFTMarketReceiverModule(mtoftInitStructLowDecimals);
        vm.label(address(mtoftMarketReceiverModuleLowDecimals), "mtoftMarketReceiverModuleLowDecimals");
        TOFTOptionsReceiverModule mtoftOptionsReceiverModuleLowDecimals = new TOFTOptionsReceiverModule(mtoftInitStructLowDecimals);
        vm.label(address(mtoftOptionsReceiverModuleLowDecimals), "mtoftOptionsReceiverModuleLowDecimals");
        TOFTGenericReceiverModule mtoftGenericReceiverModuleLowDecimals = new TOFTGenericReceiverModule(mtoftInitStructLowDecimals);
        vm.label(address(mtoftGenericReceiverModuleLowDecimals), "mtoftGenericReceiverModuleLowDecimals");

        toft = _createToft(address(underlyingErc20), aEid, address(toftSender), address(toftReceiver), address(toftMarketReceiverModule), address(toftOptionsReceiverModule), address(toftGenericReceiverModule));
        assertEq(address(toft.erc20()), address(underlyingErc20));
        toftLowDecimals = _createToft(address(underlyingLowDecimalsErc20), aEid, address(toftSenderLowDecimals), address(toftReceiverLowDecimals), address(toftMarketReceiverModuleLowDecimals), address(toftOptionsReceiverModuleLowDecimals), address(toftGenericReceiverModuleLowDecimals));
        assertEq(address(toftLowDecimals.erc20()), address(underlyingLowDecimalsErc20));
        toftEth = _createToft(address(0), aEid, address(toftSenderEth), address(toftReceiverEth), address(toftMarketReceiverModuleEth), address(toftOptionsReceiverModuleEth), address(toftGenericReceiverModuleEth));
        assertEq(address(toftEth.erc20()), address(0));
        mToft = _createMToft(address(underlyingErc20), aEid, address(mtoftSender), address(mtoftReceiver), address(mtoftMarketReceiverModule), address(mtoftOptionsReceiverModule), address(mtoftGenericReceiverModule), address(this));
        assertEq(address(mToft.erc20()), address(underlyingErc20));
        mToftLowDecimals = _createMToft(address(underlyingLowDecimalsErc20), aEid, address(mtoftSenderLowDecimals), address(mtoftReceiverLowDecimals), address(mtoftMarketReceiverModuleLowDecimals), address(mtoftOptionsReceiverModuleLowDecimals), address(mtoftGenericReceiverModuleLowDecimals), address(this));
        assertEq(address(mToftLowDecimals.erc20()), address(underlyingLowDecimalsErc20));
        mToftEth = _createMToft(address(0), aEid, address(mtoftSenderEth), address(mtoftReceiverEth), address(mtoftMarketReceiverModuleEth), address(mtoftOptionsReceiverModuleEth), address(mtoftGenericReceiverModuleEth), address(this));
        assertEq(address(mToftEth.erc20()), address(0));
    }

    // *************** //
    // *** HELPERS *** //
    // *************** //
    function _createToft(address _underlyingToken, uint32 _endpoint, address sender, address receiver, address marketReceiver, address optionsReceiver, address genericReceiver) internal returns (TOFT oft) {
        TOFTInitStruct memory initData = _createOftInitStruct(_underlyingToken, _endpoint);
        TOFTModulesInitStruct memory modulesData = _createOftModuleStruct(sender, receiver, marketReceiver, optionsReceiver, genericReceiver);

        oft = TOFT(
            payable(_deployOApp(type(TOFT).creationCode, abi.encode(initData, modulesData)))
        );
    }

    function _createMToft(address _underlyingToken, uint32 _endpoint, address sender, address receiver, address marketReceiver, address optionsReceiver, address genericReceiver, address stgRouter) internal returns (mTOFT oft) {
        TOFTInitStruct memory initData = _createOftInitStruct(_underlyingToken, _endpoint);
        TOFTModulesInitStruct memory modulesData = _createOftModuleStruct(sender, receiver, marketReceiver, optionsReceiver, genericReceiver);

        oft = mTOFT(
            payable(_deployOApp(type(mTOFT).creationCode, abi.encode(initData, modulesData, stgRouter)))
        );
    }

    // ***************** //
    // *** MODIFIERS *** //
    // ***************** //
    /// @notice Modifier to approve an operator in YB via Pearlmit.
    modifier whenApprovedViaPearlmit(
        uint256 _type,
        address _token,
        uint256 _tokenId,
        address _from,
        address _operator,
        uint256 _amount,
        uint256 _expiration
    ) {
        _approveViaPearlmit({
            tokenType: _type,
            token: _token,
            pearlmit: IPearlmit(address(pearlmit)),
            from: _from,
            operator: _operator,
            amount: _amount,
            expiration: _expiration,
            tokenId: _tokenId
        });
        _;
    }

    /// @notice Modifier to approve an operator via regular ERC20.
    modifier whenApprovedViaERC20(address _token, address _from, address _operator, uint256 _amount) {
        _approveViaERC20({token: _token, from: _from, operator: _operator, amount: _amount});
        _;
    }

    /// @notice Modifier to approve an operator for a specific asset ID via YB.
    modifier whenYieldBoxApprovedForAssetID(address _from, address _operator, uint256 _assetId) {
        _approveYieldBoxAssetId({yieldBox: yieldBox, from: _from, operator: _operator, assetId: _assetId});
        _;
    }

    /// @notice Modifier to approve an operator for a specific asset ID via YB.
    modifier whenYieldBoxApprovedForMultipleAssetIDs(address _from, address _operator, uint256 _noOfAssets) {
        for (uint256 i = 1; i <= _noOfAssets; i++) {
            _approveYieldBoxAssetId({yieldBox: yieldBox, from: _from, operator: _operator, assetId: i});
        }
        _;
    }

    /// @notice Modifier to approve an operator for all via YB.
    modifier whenYieldBoxApprovedForAll(address _from, address _operator) {
        _approveYieldBoxForAll({yieldBox: yieldBox, from: _from, operator: _operator});
        _;
    }

    /// @notice Modifier to changea user's prank.
    modifier resetPrank(address user) {
        _resetPrank(user);
        _;
    }

    /// @notice Modifier to verify a value is less than or equal to a minimum and greater than or equal to a maximum
    modifier assumeRange(uint256 value, uint256 min, uint256 max) {
        vm.assume(value >= min && value <= max);
        _;
    }

    // *************** //
    // *** PRIVATE *** //
    // *************** //
    function _createOftInitStruct(address _underlyingToken, uint32 _endpoint) internal returns (TOFTInitStruct memory) {
        TOFTVault _vault = new TOFTVault(address(_underlyingToken));
        TapiocaOmnichainExtExec _extExec = new TapiocaOmnichainExtExec();
        return TOFTInitStruct({
            name: _underlyingToken == address(0) ? "Native Token" : IERC20Metadata(_underlyingToken).name(),
            symbol: _underlyingToken == address(0) ? "NATIVE" : IERC20Metadata(_underlyingToken).symbol(),
            endpoint: address(endpoints[_endpoint]),
            delegate: address(this),
            yieldBox: address(yieldBox),
            cluster: address(cluster),
            erc20: _underlyingToken,
            vault: address(_vault),
            hostEid: _endpoint,
            extExec: address(_extExec),
            pearlmit: IPearlmit(address(pearlmit))
        });
    }
    function _createOftModuleStruct(address sender, address receiver, address marketReceiver, address optionsReceiver, address genericReceiver) internal pure returns (TOFTModulesInitStruct memory) {
        return TOFTModulesInitStruct({
                tOFTSenderModule: sender,
                tOFTReceiverModule: receiver,
                marketReceiverModule: marketReceiver,
                optionsReceiverModule: optionsReceiver,
                genericReceiverModule: genericReceiver
        });
    }
}