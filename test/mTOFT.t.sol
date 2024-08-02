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

    function test_sendPacket_success() public {
        vm.startPrank(alice);
        console.log("Bob balance in chain 2 before : ", mTOFTChain2.balanceOf(bob));
        uint200 amount = 1e18; // Amount to send: 1 token
        setApprovals(mTOFTChain1, ERC20Chain1, amount);
        mTOFTChain1.wrap(alice, alice, amount);
        LZSendParam memory lzSendParam = getLzParams(2, bob, amount, alice);

        assertEq(mTOFTChain2.balanceOf(bob), 0, "Bob balance in chain 2 should be 0 before sending");
        mTOFTChain1.sendPacket{value: 350000}(lzSendParam, "");

        verifyPackets(uint32(2), address(mTOFTChain2));
        assertEq(mTOFTChain2.balanceOf(bob), amount, "Amount transfered to Chain 2 should match sent amount");
    }
    function test_sendPacketFrom_fail_Without_TOE_Role() public {
        vm.startPrank(alice);
        uint200 amount = 1e18;
        LZSendParam memory lzSendParam = getLzParams(2, alice, amount, alice);
        vm.expectRevert();
        mTOFTChain1.sendPacketFrom{value: 300000}(alice, lzSendParam, "0x");
        vm.stopPrank();
    }

    function test_sendPacketFrom_fail_From_Zero_Address() public {
        vm.startPrank(alice);
        uint200 amount = 1e18;
        LZSendParam memory lzSendParam = getLzParams(2, alice, amount, alice);
        vm.expectRevert();
        mTOFTChain1.sendPacketFrom{value: 300000}(address(0), lzSendParam, "0x");
        vm.stopPrank();
    }

    function test_getTypedDataHash_deterministicOutput() public {
        address userA = address(0x123);
        address spender = address(0x456);
        uint256 amount = 1000;
        uint256 nonce = 0;
        uint256 deadline = block.timestamp;

        ERC20PermitStruct memory permitData =
            ERC20PermitStruct({owner: alice, spender: bob, value: amount, nonce: nonce, deadline: deadline});

        bytes32 hash1 = mTOFTChain1.getTypedDataHash(permitData);
        bytes32 hash2 = mTOFTChain1.getTypedDataHash(permitData);

        assertEq(hash1, hash2, "Hash should be deterministic for the same input");
    }

    function test_wrap_success() public {
        vm.startPrank(alice);
        uint200 amountToWrap = 1e18;
        setApprovals(mTOFTChain1, ERC20Chain1, amountToWrap);
        mTOFTChain1.wrap(alice, alice, amountToWrap);
        assertEq(mTOFTChain1.balanceOf(alice), amountToWrap, "Alice balance in mTOFTChain1 should be 1 after wrapping");
        vm.stopPrank();
    }

    function test_wrap_reverts_when_called_by_balancers() public {
        setOwnerState(mTOFTChain1, 2, true, MINT_CAP); //Set balancer address to be address(this)
        vm.expectRevert(mTOFT_BalancerNotAuthorized.selector);
        uint200 amountToWrap = 1e18;
        mTOFTChain1.wrap(msg.sender, msg.sender, amountToWrap);
    }

    function test_wrap_reverts_when_chain_not_connected() public {
        setOwnerState(mTOFTChain2, 2, false, MINT_CAP);
        vm.startPrank(alice);
        uint200 amountToWrap = 1e18;
        ERC20Chain2.mint(alice, amountToWrap);
        uint48 deadline = uint48(block.timestamp);

        // Approvals
        ERC20Chain2.approve(address(mTOFTChain2), amountToWrap);
        pearlmit.approve(20, address(ERC20Chain2), 0, address(mTOFTChain2), amountToWrap, deadline);
        ERC20Chain2.approve(address(pearlmit), amountToWrap);

        vm.expectRevert(mTOFT_NotHost.selector);
        // Wrap tokens into mTOFT
        mTOFTChain2.wrap(alice, alice, amountToWrap);
        vm.stopPrank();
    }

    function test_wrap_reverts_invalid_cap() public {
        setOwnerState(mTOFTChain1, 2, true, MINT_CAP);
        vm.startPrank(alice);
        uint200 amountToWrap = 1e18;
        ERC20Chain1.mint(alice, amountToWrap);
        uint48 deadline = uint48(block.timestamp);

        // Approvals
        ERC20Chain1.approve(address(mTOFTChain1), amountToWrap);
        pearlmit.approve(20, address(ERC20Chain1), 0, address(mTOFTChain1), amountToWrap, deadline);
        ERC20Chain1.approve(address(pearlmit), amountToWrap);

        vm.expectRevert(mTOFT_CapNotValid.selector);
        // Wrap tokens into mTOFT
        mTOFTChain1.wrap(alice, alice, MINT_CAP + 1);
        vm.stopPrank();
    }

    function test_unwrap_reverts_when_called_by_balancers() public {
        uint200 amountToUnwrap = 1e18;
        setOwnerState(mTOFTChain1, 2, true, MINT_CAP);
        vm.expectRevert(mTOFT_BalancerNotAuthorized.selector);
        mTOFTChain1.unwrap(address(this), amountToUnwrap);
    }

    function test_unwrap_reverts_when_chain_not_connected() public {
        setOwnerState(mTOFTChain1, 1, false, MINT_CAP);
        vm.startPrank(alice);
        uint200 amountToUnwrap = 1e18;
        vm.expectRevert(mTOFT_NotHost.selector);
        mTOFTChain1.unwrap(alice, amountToUnwrap);
    }

    function test_unwrap_success() public {
        vm.startPrank(alice);
        uint200 amountToUnwrap = 1e18;
        setApprovals(mTOFTChain1, ERC20Chain1, amountToUnwrap);
        mTOFTChain1.wrap(alice, alice, amountToUnwrap);
        mTOFTChain1.unwrap(alice, amountToUnwrap);
        assertEq(mTOFTChain1.balanceOf(alice), 0, "Alice balance in mTOFTChain1 should be 0 after unwrapping");
    }

    function test_sgReceive_reverts_when_caller_is_not_stargateRouter() public {
        vm.startPrank(alice);
        address _token = address(mTOFTChain1);
        uint256 amountLD = 1 ether;
        uint16 _srcChainID = 1;
        uint256 nonce = 0;
        bytes memory payload = "0x1234";
        bytes memory _srcAddress = abi.encodePacked(address(this));
        vm.expectRevert(mTOFT_NotAuthorized.selector);
        // Call the function
        mTOFTChain1.sgReceive{value: amountLD}(
            _srcChainID, // uint16
            _srcAddress, // bytes memory
            nonce, // uint256
            _token, // address
            amountLD, // uint256 amountLD
            payload // bytes memory
        );
    }

    function test_sgReceive_caller_is_stargateRouter() public {
        vm.startPrank(address(stargateRouter));
        vm.deal(address(stargateRouter), 10 ether);
        ERC20Chain1.mint(address(mTOFTChain1), 1 ether);
        address _token = address(mTOFTChain1);
        uint256 amountLD = 1 ether;
        uint16 _srcChainID = 1;
        uint256 nonce = 0;
        bytes memory payload = "0x1234";
        bytes memory _srcAddress = abi.encodePacked(address(this));

        console.log(ERC20Chain1.balanceOf(address(TOFTVaultChain1)));
        assertEq(
            ERC20Chain1.balanceOf(address(TOFTVaultChain1)), 0, "TOFTVaultChain1 balance should be 0 before sgReceive"
        );
        // Call the function
        mTOFTChain1.sgReceive{value: amountLD}(
            _srcChainID, // uint16
            _srcAddress, // bytes memory
            nonce, // uint256
            _token, // address
            amountLD, // uint256 amountLD
            payload // bytes memory
        );
        assertEq(
            ERC20Chain1.balanceOf(address(TOFTVaultChain1)),
            amountLD,
            "TOFTVaultChain1 balance should be 1 after sgReceive"
        );
    }

    function test_rescueEth_reverts_when_not_owner() public {
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        mTOFTChain1.rescueEth(1 ether, alice);
    }

    function test_rescueEth_success() public {
        vm.deal(address(mTOFTChain1), 10 ether);
        uint256 amount = 1 ether;
        uint256 balanceBefore = address(this).balance;
        mTOFTChain1.rescueEth(amount, address(this));
        uint256 balanceAfter = address(this).balance;
        assertEq(balanceAfter, balanceBefore + amount, "Contract balance should increase by the amount");
    }
    function test_setOwnerState_reverts_when_not_owner() public {
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        setOwnerState(mTOFTChain1, 2, true, MINT_CAP);
    }


    function test_withdrawFees_reverts_when_not_owner() public {
        vm.startPrank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        mTOFTChain1.withdrawFees(address(this), 1 ether);
    }

