// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.22;
// External

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20Mock} from "./ERC20Mock.sol";
// LZ
import {
    SendParam,
    MessagingFee,
    MessagingReceipt,
    OFTReceipt
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
//tapioca
import {mTOFT} from "../contracts/tOFT/mTOFT.sol";
import {Pearlmit} from "../gitmodule/tapioca-periph/contracts/pearlmit/Pearlmit.sol";
import {Cluster} from "../gitmodule/tapioca-periph/contracts/Cluster/Cluster.sol";
import {YieldBox} from "../gitmodule/tap-yieldbox/contracts/YieldBox.sol";
import {IPearlmit} from "../gitmodule/tapioca-periph/contracts/interfaces/periph/IPearlmit.sol";
import {TOFTInitStruct, LZSendParam} from "../gitmodule/tapioca-periph/contracts/interfaces/oft/ITOFT.sol";
import {TOFTVault} from "../contracts/tOFT/TOFTVault.sol";
import {TapiocaOmnichainExtExec} from "tapioca-periph/tapiocaOmnichainEngine/extension/TapiocaOmnichainExtExec.sol";
import {TOFTModulesInitStruct, ITOFT, ERC20PermitStruct} from "tapioca-periph/interfaces/oft/ITOFT.sol";
import {IMtoftFeeGetter} from "../gitmodule/tapioca-periph/contracts/interfaces/oft/IMToftFeeGetter.sol";
import {MockMtoftFeeGetter} from "./LZSetup/mocks/IMtoftFeeGetterMock.sol";
//modules
import {TOFTGenericReceiverModule} from "tapiocaz/tOFT/modules/TOFTGenericReceiverModule.sol";
import {TOFTOptionsReceiverModule} from "tapiocaz/tOFT/modules/TOFTOptionsReceiverModule.sol";
import {TOFTMarketReceiverModule} from "tapiocaz/tOFT/modules/TOFTMarketReceiverModule.sol";
import {TOFTSender} from "tapiocaz/tOFT/modules/TOFTSender.sol";
import {mTOFTReceiver} from "tapiocaz/tOFT/modules/mTOFTReceiver.sol";
//StargateRouter
import {StargateRouterMock} from "./StargateRouterMock.sol";
//test helper
import {TOFTTestHelper} from "./TOFTTestHelper.t.sol";
import {console} from "forge-std/console.sol";

contract mTOFTTest is TOFTTestHelper {
    error mTOFT_BalancerNotAuthorized();
    error mTOFT_NotHost();
    error mTOFT_CapNotValid();
    error mTOFT_NotAuthorized();
    error Ownable__CallerIsNotOwner();
    error TOFT_NotValid();

    uint16 internal constant TYPE_1 = 1; // legacy options type 1
    uint256 internal constant GAS_LIMIT = 200000;
    uint256 internal constant MINT_CAP = 1_000_000_000e18;

    address public pearlmitAddress;
    address public alice;
    address public bob;

    Pearlmit pearlmit;
    Cluster cluster;
    YieldBox yieldBox;
    ERC20Mock ERC20Chain1;
    ERC20Mock ERC20Chain2;

    TapiocaOmnichainExtExec toftExtExec;
    TOFTVault TOFTVaultChain1;
    TOFTVault TOFTVaultChain2;
    mTOFT mTOFTChain1;
    mTOFT mTOFTChain2;
    MockMtoftFeeGetter mockFeeGetter = new MockMtoftFeeGetter();

    // TOFTChain1 modules
    TOFTSender mTOFTSenderChain1;
    mTOFTReceiver mTOFTReceiverChain1;
    TOFTMarketReceiverModule mTOFTMarketReceiverModuleChain1;
    TOFTOptionsReceiverModule mTOFTOptionsReceiverModuleChain1;
    TOFTGenericReceiverModule mTOFTGenericReceiverModuleChain1;

    // TOFTChain2 modules
    TOFTSender mTOFTSenderChain2;
    mTOFTReceiver mTOFTReceiverChain2;
    TOFTMarketReceiverModule mTOFTMarketReceiverModuleChain2;
    TOFTOptionsReceiverModule mTOFTOptionsReceiverModuleChain2;
    TOFTGenericReceiverModule mTOFTGenericReceiverModuleChain2;

    // StargateRouter
    StargateRouterMock stargateRouter;

    struct SetOwnerStateData {
        address stargateRouter;
        IMtoftFeeGetter feeGetter;
        uint256 mintCap;
        uint256 connectedChain;
        bool connectedChainState;
        address balancerStateAddress;
        bool balancerState;
    }

    function setUp() public virtual override {
        //// address setup ////
        pearlmitAddress = makeAddr("pearlmit");
        vm.label(pearlmitAddress, "PearlmitAddress");
        alice = makeAddr("alice");
        vm.label(alice, "Alice");
        vm.deal(alice, 10 ether); // Fund Alice with ether for transaction fees

        bob = makeAddr("bob");
        vm.label(bob, "Bob");
        //// contracts setup ////
        pearlmit = new Pearlmit("mTOFT", "1", pearlmitAddress, 0);
        cluster = new Cluster(1, address(this));
        yieldBox = createYieldBox(pearlmit, address(this));
        ERC20Chain1 = new ERC20Mock("ErcChain1", "ErcChain1");
        ERC20Chain2 = new ERC20Mock("ErcChain2", "ErcTChain2");

        TOFTVaultChain1 = new TOFTVault(address(ERC20Chain1));
        TOFTVaultChain2 = new TOFTVault(address(ERC20Chain2));

        toftExtExec = new TapiocaOmnichainExtExec();

        // Mint some tokens on Chain 1
        ERC20Chain1.mint(alice, 10 ether);
        ERC20Chain1.mint(address(this), 10 ether);
        ////////////////////////////////////////////////
        /////////////// SETUP CHAIN 1 //////////////////
        ////////////////////////////////////////////////

        //setup endpoint
        setUpEndpoints(2, LibraryType.UltraLightNode);

        //initialize TOFT data for chain 1
        TOFTInitStruct memory initToftDataChain1 = initTOFTData(
            "ErcChain1",
            "ERC1",
            endpoints[1], // Use endpoint for Chain 1
            address(this),
            address(yieldBox),
            address(cluster),
            address(ERC20Chain1),
            address(TOFTVaultChain1),
            1,
            address(toftExtExec),
            IPearlmit(address(pearlmit))
        );

        //initialize TOFT modules
        mTOFTSenderChain1 = new TOFTSender(initToftDataChain1);
        vm.label(address(mTOFTSenderChain1), "mTOFTSenderChain1");
        mTOFTReceiverChain1 = new mTOFTReceiver(initToftDataChain1);
        vm.label(address(mTOFTReceiverChain1), "mTOFTReceiverChain1");
        mTOFTMarketReceiverModuleChain1 = new TOFTMarketReceiverModule(initToftDataChain1);
        vm.label(address(mTOFTMarketReceiverModuleChain1), "mTOFTMarketReceiverModuleChain1");
        mTOFTOptionsReceiverModuleChain1 = new TOFTOptionsReceiverModule(initToftDataChain1);
        vm.label(address(mTOFTOptionsReceiverModuleChain1), "mTOFTOptionsReceiverModuleChain1");
        mTOFTGenericReceiverModuleChain1 = new TOFTGenericReceiverModule(initToftDataChain1);
        vm.label(address(mTOFTGenericReceiverModuleChain1), "mTOFTGenericReceiverModuleChain1");
        // setup TOFTmodulesInitStruct
        TOFTModulesInitStruct memory mTOFTModulesInitStructChain1 = TOFTModulesInitStruct({
            tOFTSenderModule: address(mTOFTSenderChain1),
            tOFTReceiverModule: address(mTOFTReceiverChain1),
            marketReceiverModule: address(mTOFTMarketReceiverModuleChain1),
            optionsReceiverModule: address(mTOFTOptionsReceiverModuleChain1),
            genericReceiverModule: address(mTOFTGenericReceiverModuleChain1)
        });

        stargateRouter = new StargateRouterMock(IERC20(address(ERC20Chain1)));
        vm.label(address(stargateRouter), "StargateRouter");

        mTOFTChain1 = new mTOFT(initToftDataChain1, mTOFTModulesInitStructChain1, address(stargateRouter));
        vm.label(address(mTOFTChain1), "mTOFTChain1");

        ////////////////////////////////////////////////
        /////////////// SETUP CHAIN 2 //////////////////
        ////////////////////////////////////////////////

        TOFTInitStruct memory initToftDataChain2 = initTOFTData(
            "ErcChain2",
            "ERC2",
            endpoints[2], // Use endpoint for Chain 2
            address(this),
            address(yieldBox),
            address(cluster),
            address(ERC20Chain2),
            address(TOFTVaultChain2),
            2, // Use EID 2 for Chain 2
            address(toftExtExec),
            IPearlmit(address(pearlmit))
        );

        //initialize TOFT modules for Chain 2
        mTOFTSenderChain2 = new TOFTSender(initToftDataChain2);
        vm.label(address(mTOFTSenderChain2), "mTOFTSenderChain2");
        mTOFTReceiverChain2 = new mTOFTReceiver(initToftDataChain2);
        vm.label(address(mTOFTReceiverChain2), "mTOFTReceiverChain2");
        mTOFTMarketReceiverModuleChain2 = new TOFTMarketReceiverModule(initToftDataChain2);
        vm.label(address(mTOFTMarketReceiverModuleChain2), "mTOFTMarketReceiverModuleChain2");
        mTOFTOptionsReceiverModuleChain2 = new TOFTOptionsReceiverModule(initToftDataChain2);
        vm.label(address(mTOFTOptionsReceiverModuleChain2), "mTOFTOptionsReceiverModuleChain2");
        mTOFTGenericReceiverModuleChain2 = new TOFTGenericReceiverModule(initToftDataChain2);
        vm.label(address(mTOFTGenericReceiverModuleChain2), "mTOFTGenericReceiverModuleChain2");

        TOFTModulesInitStruct memory mTOFTModulesInitStructChain2 = TOFTModulesInitStruct({
            tOFTSenderModule: address(mTOFTSenderChain2),
            tOFTReceiverModule: address(mTOFTReceiverChain2),
            marketReceiverModule: address(mTOFTMarketReceiverModuleChain2),
            optionsReceiverModule: address(mTOFTOptionsReceiverModuleChain2),
            genericReceiverModule: address(mTOFTGenericReceiverModuleChain2)
        });

        mTOFTChain2 = new mTOFT(initToftDataChain2, mTOFTModulesInitStructChain2, address(stargateRouter));

        vm.label(address(mTOFTChain2), "mTOFTChain2");

        address[] memory ofts = new address[](2);
        ofts[0] = address(mTOFTChain1);
        ofts[1] = address(mTOFTChain2);
        this.wireOApps(ofts);
    }

    function test_send_success() public {
        vm.deal(alice, 1 ether); // Fund Alice with ether for transaction fees
        vm.startPrank(alice);
        uint256 EthBalanceBefore = address(alice).balance;
        uint200 amount = 1e18; // Amount to send: 1 token
        uint32 dstEid = 2; // Destination chain ID (Chain 2)
        bytes32 to = bytes32(uint256(uint160(alice))); // Convert Alice's address to bytes32

        setApprovals(mTOFTChain1, ERC20Chain1, amount);
        mTOFTChain1.wrap(alice, alice, amount);
        // Prepare SendParam
        SendParam memory sendParam = SendParam({
            dstEid: dstEid,
            to: to,
            amountLD: amount,
            minAmountLD: amount, // Set min amount equal to sent amount for this test
            extraOptions: abi.encodePacked(TYPE_1, GAS_LIMIT),
            composeMsg: "0x",
            oftCmd: "0x"
        });

        // Prepare MessagingFee
        uint256 _nativeFee = 210526; // Amount of fee needed for send
        MessagingFee memory fee = MessagingFee({nativeFee: _nativeFee, lzTokenFee: 0});

        // Call send function
        (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt) =
            mTOFTChain1.send{value: fee.nativeFee}(sendParam, fee, alice);

        verifyPackets(uint32(2), address(mTOFTChain2));
        uint256 EthBalanceAfter = address(alice).balance;

        uint256 amountInChain2 = mTOFTChain2.balanceOf(alice);
        assertEq(amountInChain2, amount, "Amount transfered to Chain 2 should match sent amount");
        assertEq(mTOFTChain1.balanceOf(alice), 0, "Alice balance on Chain 1 should be 0 after sending to Chain 2");
        assertNotEq(msgReceipt.guid, bytes32(0), "GUID should not be empty");
        assertEq(EthBalanceBefore, EthBalanceAfter + _nativeFee, "Fee paid should be deducted from Alice's balance");
        vm.stopPrank();
    }

