// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.22;

// LZ
import {
    SendParam,
    MessagingFee,
    MessagingReceipt,
    OFTReceipt
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";

// External
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Tapioca
import {
    ITOFT,
    LZSendParam,
    ERC20PermitStruct,
    ERC20PermitApprovalMsg,
    RemoteTransferMsg,
    TOFTInitStruct,
    TOFTModulesInitStruct,
    MarketBorrowMsg,
    MarketRemoveCollateralMsg,
    SendParamsMsg,
    ExerciseOptionsMsg,
    IBorrowParams,
    IRemoveParams,
    LeverageUpActionMsg
} from "tapioca-periph/interfaces/oft/ITOFT.sol";
import {
    YieldBoxApproveAllMsg,
    MarketPermitActionMsg,
    YieldBoxApproveAssetMsg
} from "tapioca-periph/interfaces/periph/ITapiocaOmnichainEngine.sol";
import {
    ITapiocaOptionBroker, IExerciseOptionsData
} from "tapioca-periph/interfaces/tap-token/ITapiocaOptionBroker.sol";
import {
    TOFTHelper,
    PrepareLzCallData,
    PrepareLzCallReturn,
    ComposeMsgData
} from "contracts/tOFT/extensions/TOFTHelper.sol";
import {TapiocaOmnichainExtExec} from "tapioca-periph/tapiocaOmnichainEngine/extension/TapiocaOmnichainExtExec.sol";
import {TOFTGenericReceiverModule} from "contracts/tOFT/modules/TOFTGenericReceiverModule.sol";
import {TOFTOptionsReceiverModule} from "contracts/tOFT/modules/TOFTOptionsReceiverModule.sol";
import {TOFTMarketReceiverModule} from "contracts/tOFT/modules/TOFTMarketReceiverModule.sol";
import {MagnetarWithdrawData} from "tapioca-periph/interfaces/periph/IMagnetar.sol";
import {ERC20WithoutStrategy} from "yieldbox/strategies/ERC20WithoutStrategy.sol";
import {Pearlmit, IPearlmit} from "tapioca-periph/pearlmit/Pearlmit.sol";
import {mTOFTReceiver} from "contracts/tOFT/modules/mTOFTReceiver.sol";
import {ICluster, Cluster} from "tapioca-periph/Cluster/Cluster.sol";
import {TOFTSender} from "contracts/tOFT/modules/TOFTSender.sol";
import {Pearlmit} from "tapioca-periph/pearlmit/Pearlmit.sol";
import {YieldBox} from "yieldbox/YieldBox.sol";

// Tapioca Tests
import {TapiocaOptionsBrokerMock} from "./TapiocaOptionsBrokerMock.sol";
import {MarketHelperMock} from "./MarketHelperMock.sol";
import {TOFTVault} from "contracts/tOFT/TOFTVault.sol";
import {TOFTTestHelper} from "./TOFTTestHelper.t.sol";
import {SingularityMock} from "./SingularityMock.sol";
import {MagnetarMock} from "./MagnetarMock.sol";
import {ERC20Mock} from "./ERC20Mock.sol";
import {TOFTMock} from "./TOFTMock.sol";

contract TOFTTest is TOFTTestHelper {
    using OptionsBuilder for bytes;
    using OFTMsgCodec for bytes32;
    using OFTMsgCodec for bytes;

    uint32 aEid = 1;
    uint32 bEid = 2;

    Pearlmit pearlmit;
    YieldBox yieldBox;
    Cluster cluster;
    ERC20Mock aERC20;
    ERC20Mock bERC20;
    ERC20Mock tapOFT;

    TOFTMock aTOFT;
    TOFTMock bTOFT;
    // MagnetarV2 magnetar;
    MagnetarMock magnetar;
    SingularityMock singularity;
    MarketHelperMock marketHelper;

    TOFTHelper tOFTHelper;

    TapiocaOptionsBrokerMock tOB;

    uint256 aTOFTYieldBoxId;
    uint256 bTOFTYieldBoxId;

    uint256 internal userAPKey = 0x1;
    uint256 internal userBPKey = 0x2;
    address public userA = vm.addr(userAPKey);
    address public userB = vm.addr(userBPKey);
    uint256 public initialBalance = 100 ether;

    /**
     * DEPLOY setup addresses
     */
    address __endpoint;
    uint256 __hostEid = aEid;
    address __owner = address(this);

    uint16 internal constant SEND = 1; // Send LZ message type
    uint16 internal constant PT_APPROVALS = 500; // Use for ERC20Permit approvals
    uint16 internal constant PT_YB_APPROVE_ASSET = 503; // Use for YieldBox 'setApprovalForAsset(true)' operation
    uint16 internal constant PT_YB_APPROVE_ALL = 504; // Use for YieldBox 'setApprovalForAll(true)' operation
    uint16 internal constant PT_MARKET_PERMIT = 505; // Use for market.permitLend() operation
    uint16 internal constant PT_REMOTE_TRANSFER = 700; // Use for transferring tokens from the contract from another chain
    uint16 internal constant PT_MARKET_REMOVE_COLLATERAL = 800; // Use for remove collateral from a market available on another chain
    uint16 internal constant PT_YB_SEND_SGL_BORROW = 801; // Use fror send to YB and/or borrow from a market available on another chain
    uint16 internal constant PT_TAP_EXERCISE = 802; // Use for exercise options on tOB available on another chain
    uint16 internal constant PT_SEND_PARAMS = 803; // Use for perform a normal OFT send but with a custom payload
    uint16 internal constant PT_LEVERAGE_UP = 805;
    uint16 internal constant PT_XCHAIN_LEND_XCHAIN_LOCK = 806; // Use for `magnetar.mintFromBBAndSendForLending` step 2 call

    /**
     * @dev TOFT global event checks
     */
    event OFTReceived(bytes32, address, uint256, uint256);
    event ComposeReceived(uint16 indexed msgType, bytes32 indexed guid, bytes composeMsg);

    /**
     * @dev Setup the OApps by deploying them and setting up the endpoints.
     */
    function setUp() public override {
        vm.deal(userA, 1000 ether);
        vm.deal(userB, 1000 ether);
        vm.label(userA, "userA");
        vm.label(userB, "userB");

        aERC20 = new ERC20Mock("Token A", "TNKA");
        bERC20 = new ERC20Mock("Token B", "TNKB");
        tapOFT = new ERC20Mock("Tapioca OFT", "TAP");
        vm.label(address(aERC20), "aERC20");
        vm.label(address(bERC20), "bERC20");
        vm.label(address(tapOFT), "tapOFT");

        setUpEndpoints(3, LibraryType.UltraLightNode);

        pearlmit = new Pearlmit("Pearlmit", "1");
        yieldBox = createYieldBox();
        cluster = createCluster(aEid, __owner);
        pearlmit = new Pearlmit("Pearlmit", "1");
        magnetar = createMagnetar(address(cluster), IPearlmit(address(pearlmit)));

        {
            vm.label(address(endpoints[aEid]), "aEndpoint");
            vm.label(address(endpoints[bEid]), "bEndpoint");
            vm.label(address(yieldBox), "YieldBox");
            vm.label(address(cluster), "Cluster");
            vm.label(address(magnetar), "Magnetar");
        }

        TapiocaOmnichainExtExec toftExtExec = new TapiocaOmnichainExtExec(ICluster(address(cluster)), __owner);
        TOFTVault aTOFTVault = new TOFTVault(address(aERC20));
        TOFTInitStruct memory aTOFTInitStruct = TOFTInitStruct({
            name: "Token A",
            symbol: "TNKA",
            endpoint: address(endpoints[aEid]),
            delegate: __owner,
            yieldBox: address(yieldBox),
            cluster: address(cluster),
            erc20: address(aERC20),
            vault: address(aTOFTVault),
            hostEid: aEid,
            extExec: address(toftExtExec),
            pearlmit: IPearlmit(address(pearlmit))
        });
        {
            TOFTSender aTOFTSender = new TOFTSender(aTOFTInitStruct);
            mTOFTReceiver aTOFTReceiver = new mTOFTReceiver(aTOFTInitStruct);
            TOFTMarketReceiverModule aTOFTMarketReceiverModule = new TOFTMarketReceiverModule(aTOFTInitStruct);
            TOFTOptionsReceiverModule aTOFTOptionsReceiverModule = new TOFTOptionsReceiverModule(aTOFTInitStruct);
            TOFTGenericReceiverModule aTOFTGenericReceiverModule = new TOFTGenericReceiverModule(aTOFTInitStruct);
            vm.label(address(aTOFTSender), "aTOFTSender");
            vm.label(address(aTOFTReceiver), "aTOFTReceiver");
            vm.label(address(aTOFTMarketReceiverModule), "aTOFTMarketReceiverModule");
            vm.label(address(aTOFTOptionsReceiverModule), "aTOFTOptionsReceiverModule");
            vm.label(address(aTOFTGenericReceiverModule), "aTOFTGenericReceiverModule");
            TOFTModulesInitStruct memory aTOFTModulesInitStruct = TOFTModulesInitStruct({
                tOFTSenderModule: address(aTOFTSender),
                tOFTReceiverModule: address(aTOFTReceiver),
                marketReceiverModule: address(aTOFTMarketReceiverModule),
                optionsReceiverModule: address(aTOFTMarketReceiverModule),
                genericReceiverModule: address(aTOFTGenericReceiverModule)
            });

            aTOFT = TOFTMock(
                payable(_deployOApp(type(TOFTMock).creationCode, abi.encode(aTOFTInitStruct, aTOFTModulesInitStruct)))
            );
            vm.label(address(aTOFT), "aTOFT");
        }

        TOFTVault bTOFTVault = new TOFTVault(address(bERC20));
        TOFTInitStruct memory bTOFTInitStruct = TOFTInitStruct({
            name: "Token B",
            symbol: "TNKB",
            endpoint: address(endpoints[bEid]),
            delegate: __owner,
            yieldBox: address(yieldBox),
            cluster: address(cluster),
            erc20: address(bERC20),
            vault: address(bTOFTVault),
            hostEid: bEid,
            extExec: address(toftExtExec),
            pearlmit: IPearlmit(address(pearlmit))
        });
        {
            TOFTSender bTOFTSender = new TOFTSender(bTOFTInitStruct);
            mTOFTReceiver bTOFTReceiver = new mTOFTReceiver(bTOFTInitStruct);
            TOFTMarketReceiverModule bTOFTMarketReceiverModule = new TOFTMarketReceiverModule(bTOFTInitStruct);
            TOFTOptionsReceiverModule bTOFTOptionsReceiverModule = new TOFTOptionsReceiverModule(bTOFTInitStruct);
            TOFTGenericReceiverModule bTOFTGenericReceiverModule = new TOFTGenericReceiverModule(bTOFTInitStruct);
            vm.label(address(bTOFTSender), "bTOFTSender");
            vm.label(address(bTOFTReceiver), "bTOFTReceiver");
            vm.label(address(bTOFTMarketReceiverModule), "bTOFTMarketReceiverModule");
            vm.label(address(bTOFTOptionsReceiverModule), "bTOFTOptionsReceiverModule");
            vm.label(address(bTOFTGenericReceiverModule), "bTOFTGenericReceiverModule");
            TOFTModulesInitStruct memory bTOFTModulesInitStruct = TOFTModulesInitStruct({
                tOFTSenderModule: address(bTOFTSender),
                tOFTReceiverModule: address(bTOFTReceiver),
                marketReceiverModule: address(bTOFTMarketReceiverModule),
                optionsReceiverModule: address(bTOFTOptionsReceiverModule),
                genericReceiverModule: address(bTOFTGenericReceiverModule)
            });
            bTOFT = TOFTMock(
                payable(_deployOApp(type(TOFTMock).creationCode, abi.encode(bTOFTInitStruct, bTOFTModulesInitStruct)))
            );
            vm.label(address(bTOFT), "bTOFT");
        }

        tOFTHelper = new TOFTHelper();
        vm.label(address(tOFTHelper), "TOFTHelper");

        // config and wire the ofts
        address[] memory ofts = new address[](2);
        ofts[0] = address(aTOFT);
        ofts[1] = address(bTOFT);
        this.wireOApps(ofts);

        // Setup YieldBox assets
        ERC20WithoutStrategy aTOFTStrategy = createYieldBoxEmptyStrategy(address(yieldBox), address(aTOFT));
        ERC20WithoutStrategy bTOFTStrategy = createYieldBoxEmptyStrategy(address(yieldBox), address(bTOFT));

        aTOFTYieldBoxId = registerYieldBoxAsset(address(yieldBox), address(aTOFT), address(aTOFTStrategy)); //we assume this is the asset Id
        bTOFTYieldBoxId = registerYieldBoxAsset(address(yieldBox), address(bTOFT), address(bTOFTStrategy)); //we assume this is the collateral Id

        singularity =
            createSingularity(address(yieldBox), bTOFTYieldBoxId, aTOFTYieldBoxId, address(bTOFT), address(aTOFT));
        vm.label(address(singularity), "Singularity");

        tOB = new TapiocaOptionsBrokerMock(address(tapOFT), IPearlmit(address(pearlmit)));

        marketHelper = new MarketHelperMock();

        cluster.updateContract(aEid, address(yieldBox), true);
        cluster.updateContract(aEid, address(singularity), true);
        cluster.updateContract(aEid, address(magnetar), true);
        cluster.updateContract(aEid, address(tOB), true);
        cluster.updateContract(aEid, address(marketHelper), true);
        cluster.updateContract(bEid, address(yieldBox), true);
        cluster.updateContract(bEid, address(singularity), true);
        cluster.updateContract(bEid, address(magnetar), true);
        cluster.updateContract(bEid, address(tOB), true);
        cluster.updateContract(bEid, address(marketHelper), true);
    }

    /**
     * =================
     *      HELPERS
     * =================
     */

    /**
     * @dev Used to bypass stack too deep
     *
     * @param msgType The message type of the lz Compose.
     * @param guid The message GUID.
     * @param composeMsg The source raw OApp compose message. If compose msg is composed with other msgs,
     * the msg should contain only the compose msg at its index and forward. I.E composeMsg[currentIndex:]
     * @param dstEid The destination EID.
     * @param from The address initiating the composition, typically the OApp where the lzReceive was called.
     * @param to The address of the lzCompose receiver.
     * @param srcMsgSender The address of src EID OFT `msg.sender` call initiator .
     * @param extraOptions The options passed in the source OFT call. Only restriction is to have it contain the actual compose option for the index,
     * whether there are other composed calls or not.
     */
    struct LzOFTComposedData {
        uint16 msgType;
        bytes32 guid;
        bytes composeMsg;
        uint32 dstEid;
        address from;
        address to;
        address srcMsgSender;
        bytes extraOptions;
    }
    /**
     * @notice Call lzCompose on the destination OApp.
     *
     * @dev Be sure to verify the message by calling `TestHelper.verifyPackets()`.
     * @dev Will internally verify the emission of the `ComposeReceived` event with
     * the right msgType, GUID and lzReceive composer message.
     *
     * @param _lzOFTComposedData The data to pass to the lzCompose call.
     */

    function __callLzCompose(LzOFTComposedData memory _lzOFTComposedData) internal {
        vm.expectEmit(true, true, true, false);
        emit ComposeReceived(_lzOFTComposedData.msgType, _lzOFTComposedData.guid, _lzOFTComposedData.composeMsg);

        this.lzCompose(
            _lzOFTComposedData.dstEid,
            _lzOFTComposedData.from,
            _lzOFTComposedData.extraOptions,
            _lzOFTComposedData.guid,
            _lzOFTComposedData.to,
            abi.encodePacked(
                OFTMsgCodec.addressToBytes32(_lzOFTComposedData.srcMsgSender), _lzOFTComposedData.composeMsg
            )
        );
    }

    function test_constructor() public {
        assertEq(address(aTOFT.yieldBox()), address(yieldBox));
        assertEq(address(aTOFT.cluster()), address(cluster));
        assertEq(address(aTOFT.erc20()), address(aERC20));
        assertEq(aTOFT.hostEid(), aEid);
    }

    function test_erc20_permit() public {
        ERC20PermitStruct memory permit_ =
            ERC20PermitStruct({owner: userA, spender: userB, value: 1e18, nonce: 0, deadline: 1 days});

        bytes32 digest_ = aTOFT.getTypedDataHash(permit_);
        ERC20PermitApprovalMsg memory permitApproval_ =
            __getERC20PermitData(permit_, digest_, address(aTOFT), userAPKey);

        aTOFT.permit(
            permit_.owner,
            permit_.spender,
            permit_.value,
            permit_.deadline,
            permitApproval_.v,
            permitApproval_.r,
            permitApproval_.s
        );
        assertEq(aTOFT.allowance(userA, userB), 1e18);
        assertEq(aTOFT.nonces(userA), 1);
    }

    function test_leverage_up() public {
        uint256 erc20Amount_ = 1 ether;

        //setup
        {
            deal(address(aTOFT), address(this), erc20Amount_);
            aTOFT.approve(address(yieldBox), type(uint256).max);
            yieldBox.depositAsset(aTOFTYieldBoxId, address(this), address(singularity), erc20Amount_, 0);

            deal(address(bTOFT), address(this), erc20Amount_);
            bTOFT.approve(address(yieldBox), type(uint256).max);
            yieldBox.depositAsset(bTOFTYieldBoxId, address(this), address(singularity), erc20Amount_, 0);
        }

        //useful in case of withdraw after borrow
        LZSendParam memory withdrawLzSendParam_;
        MessagingFee memory withdrawMsgFee_; // Will be used as value for the composed msg

        {
            // @dev `withdrawMsgFee_` is to be airdropped on dst to pay for the send to source operation (B->A).
            PrepareLzCallReturn memory prepareLzCallReturn1_ = tOFTHelper.prepareLzCall( // B->A data
                ITOFT(address(bTOFT)),
                PrepareLzCallData({
                    dstEid: aEid,
                    recipient: OFTMsgCodec.addressToBytes32(address(this)),
                    amountToSendLD: erc20Amount_,
                    minAmountToCreditLD: erc20Amount_,
                    msgType: SEND,
                    composeMsgData: ComposeMsgData({
                        index: 0,
                        gas: 0,
                        value: 0,
                        data: bytes(""),
                        prevData: bytes(""),
                        prevOptionsData: bytes("")
                    }),
                    lzReceiveGas: 500_000,
                    lzReceiveValue: 0
                })
            );
            withdrawLzSendParam_ = prepareLzCallReturn1_.lzSendParam;
            withdrawMsgFee_ = prepareLzCallReturn1_.msgFee;
        }

        /**
         * Actions
         */
        uint256 tokenAmountSD = tOFTHelper.toSD(erc20Amount_, aTOFT.decimalConversionRate());

        //approve magnetar
        LeverageUpActionMsg memory leverageMsg = LeverageUpActionMsg({
            user: address(this),
            market: address(singularity),
            marketHelper: address(marketHelper),
            borrowAmount: tokenAmountSD,
            supplyAmount: 0,
            executorData: "0x"
        });

        bytes memory sendMsg_ = tOFTHelper.buildLeverageUpMsg(leverageMsg);

        PrepareLzCallReturn memory prepareLzCallReturn2_ = tOFTHelper.prepareLzCall(
            ITOFT(address(aTOFT)),
            PrepareLzCallData({
                dstEid: bEid,
                recipient: OFTMsgCodec.addressToBytes32(address(this)),
                amountToSendLD: 0,
                minAmountToCreditLD: 0,
                msgType: PT_LEVERAGE_UP,
                composeMsgData: ComposeMsgData({
                    index: 0,
                    gas: 500_000,
                    value: uint128(withdrawMsgFee_.nativeFee),
                    data: sendMsg_,
                    prevData: bytes(""),
                    prevOptionsData: bytes("")
                }),
                lzReceiveGas: 500_000,
                lzReceiveValue: 0
            })
        );
        bytes memory composeMsg_ = prepareLzCallReturn2_.composeMsg;
        bytes memory oftMsgOptions_ = prepareLzCallReturn2_.oftMsgOptions;
        MessagingFee memory msgFee_ = prepareLzCallReturn2_.msgFee;
        LZSendParam memory lzSendParam_ = prepareLzCallReturn2_.lzSendParam;

        (MessagingReceipt memory msgReceipt_,) = aTOFT.sendPacket{value: msgFee_.nativeFee}(lzSendParam_, composeMsg_);

        {
            verifyPackets(uint32(bEid), address(bTOFT));

            __callLzCompose(
                LzOFTComposedData(
                    PT_LEVERAGE_UP,
                    msgReceipt_.guid,
                    composeMsg_,
                    bEid,
                    address(bTOFT), // Compose creator (at lzReceive)
                    address(bTOFT), // Compose receiver (at lzCompose)
                    address(this),
                    oftMsgOptions_
                )
            );
        }
    }

    /**
     * ERC20 APPROVALS
     */
    function test_tOFT_erc20_approvals() public {
        address userC_ = vm.addr(0x3);

        ERC20PermitApprovalMsg memory permitApprovalB_;
        ERC20PermitApprovalMsg memory permitApprovalC_;
        bytes memory approvalsMsg_;

        {
            ERC20PermitStruct memory approvalUserB_ =
                ERC20PermitStruct({owner: userA, spender: userB, value: 1e18, nonce: 0, deadline: 1 days});
            ERC20PermitStruct memory approvalUserC_ = ERC20PermitStruct({
                owner: userA,
                spender: userC_,
                value: 2e18,
                nonce: 1, // Nonce is 1 because we already called permit() on userB
                deadline: 2 days
            });

            permitApprovalB_ =
                __getERC20PermitData(approvalUserB_, bTOFT.getTypedDataHash(approvalUserB_), address(bTOFT), userAPKey);

            permitApprovalC_ =
                __getERC20PermitData(approvalUserC_, bTOFT.getTypedDataHash(approvalUserC_), address(bTOFT), userAPKey);

            ERC20PermitApprovalMsg[] memory approvals_ = new ERC20PermitApprovalMsg[](2);
            approvals_[0] = permitApprovalB_;
            approvals_[1] = permitApprovalC_;

            approvalsMsg_ = tOFTHelper.encodeERC20PermitApprovalMsg(approvals_);
        }

        PrepareLzCallReturn memory prepareLzCallReturn_ = tOFTHelper.prepareLzCall(
            ITOFT(address(aTOFT)),
            PrepareLzCallData({
                dstEid: bEid,
                recipient: OFTMsgCodec.addressToBytes32(address(this)),
                amountToSendLD: 0,
                minAmountToCreditLD: 0,
                msgType: PT_APPROVALS,
                composeMsgData: ComposeMsgData({
                    index: 0,
                    gas: 1_000_000,
                    value: 0,
                    data: approvalsMsg_,
                    prevData: bytes(""),
                    prevOptionsData: bytes("")
                }),
                lzReceiveGas: 1_000_000,
                lzReceiveValue: 0
            })
        );
        bytes memory composeMsg_ = prepareLzCallReturn_.composeMsg;
        bytes memory oftMsgOptions_ = prepareLzCallReturn_.oftMsgOptions;
        MessagingFee memory msgFee_ = prepareLzCallReturn_.msgFee;
        LZSendParam memory lzSendParam_ = prepareLzCallReturn_.lzSendParam;

        (MessagingReceipt memory msgReceipt_,) = aTOFT.sendPacket{value: msgFee_.nativeFee}(lzSendParam_, composeMsg_);

        verifyPackets(uint32(bEid), address(bTOFT));

        vm.expectEmit(true, true, true, false);
        emit IERC20.Approval(userA, userB, 1e18);

        vm.expectEmit(true, true, true, false);
        emit IERC20.Approval(userA, userC_, 1e18);

        __callLzCompose(
            LzOFTComposedData(
                PT_APPROVALS,
                msgReceipt_.guid,
                composeMsg_,
                bEid,
                address(bTOFT), // Compose creator (at lzReceive)
                address(bTOFT), // Compose receiver (at lzCompose)
                address(this),
                oftMsgOptions_
            )
        );

        assertEq(bTOFT.allowance(userA, userB), 1e18);
        assertEq(bTOFT.allowance(userA, userC_), 2e18);
        assertEq(bTOFT.nonces(userA), 2);
    }

    function test_remote_transfer() public {
        // vars
        uint256 tokenAmount_ = 1 ether;
        LZSendParam memory remoteLzSendParam_;
        MessagingFee memory remoteMsgFee_; // Will be used as value for the composed msg

        /**
         * Setup
         */
        {
            deal(address(bTOFT), address(this), tokenAmount_);

            // @dev `remoteMsgFee_` is to be airdropped on dst to pay for the `remoteTransfer` operation (B->A).
            PrepareLzCallReturn memory prepareLzCallReturn1_ = tOFTHelper.prepareLzCall( // B->A data
                ITOFT(address(bTOFT)),
                PrepareLzCallData({
                    dstEid: aEid,
                    recipient: OFTMsgCodec.addressToBytes32(address(this)),
                    amountToSendLD: tokenAmount_,
                    minAmountToCreditLD: tokenAmount_,
                    msgType: SEND,
                    composeMsgData: ComposeMsgData({
                        index: 0,
                        gas: 0,
                        value: 0,
                        data: bytes(""),
                        prevData: bytes(""),
                        prevOptionsData: bytes("")
                    }),
                    lzReceiveGas: 500_000,
                    lzReceiveValue: 0
                })
            );
            remoteLzSendParam_ = prepareLzCallReturn1_.lzSendParam;
            remoteMsgFee_ = prepareLzCallReturn1_.msgFee;
        }

        /**
         * Actions
         */
        RemoteTransferMsg memory remoteTransferData =
            RemoteTransferMsg({composeMsg: new bytes(0), owner: address(this), lzSendParam: remoteLzSendParam_});
        bytes memory remoteTransferMsg_ = tOFTHelper.buildRemoteTransferMsg(remoteTransferData);

        PrepareLzCallReturn memory prepareLzCallReturn2_ = tOFTHelper.prepareLzCall(
            ITOFT(address(aTOFT)),
            PrepareLzCallData({
                dstEid: bEid,
                recipient: OFTMsgCodec.addressToBytes32(address(this)),
                amountToSendLD: 0,
                minAmountToCreditLD: 0,
                msgType: PT_REMOTE_TRANSFER,
                composeMsgData: ComposeMsgData({
                    index: 0,
                    gas: 500_000,
                    value: uint128(remoteMsgFee_.nativeFee), // TODO Should we care about verifying cast boundaries?
                    data: remoteTransferMsg_,
                    prevData: bytes(""),
                    prevOptionsData: bytes("")
                }),
                lzReceiveGas: 500_000,
                lzReceiveValue: 0
            })
        );
        bytes memory composeMsg_ = prepareLzCallReturn2_.composeMsg;
        bytes memory oftMsgOptions_ = prepareLzCallReturn2_.oftMsgOptions;
        MessagingFee memory msgFee_ = prepareLzCallReturn2_.msgFee;
        LZSendParam memory lzSendParam_ = prepareLzCallReturn2_.lzSendParam;

        (MessagingReceipt memory msgReceipt_,) = aTOFT.sendPacket{value: msgFee_.nativeFee}(lzSendParam_, composeMsg_);

        {
            verifyPackets(uint32(bEid), address(bTOFT));

            // Initiate approval
            bTOFT.approve(address(bTOFT), tokenAmount_); // Needs to be pre approved on B chain to be able to transfer

            __callLzCompose(
                LzOFTComposedData(
                    PT_REMOTE_TRANSFER,
                    msgReceipt_.guid,
                    composeMsg_,
                    bEid,
                    address(bTOFT), // Compose creator (at lzReceive)
                    address(bTOFT), // Compose receiver (at lzCompose)
                    address(this),
                    oftMsgOptions_
                )
            );
        }

        // Check arrival
        {
            assertEq(aTOFT.balanceOf(address(this)), 0);
            verifyPackets(uint32(aEid), address(aTOFT)); // Verify B->A transfer
            assertEq(aTOFT.balanceOf(address(this)), tokenAmount_);
        }
    }

    function test_market_deposit_and_borrow() public {
        uint256 erc20Amount_ = 1 ether;

        {
            // test wrap
            deal(address(aERC20), address(this), erc20Amount_);
            deal(address(bERC20), address(this), erc20Amount_);

            assertEq(aERC20.balanceOf(address(this)), erc20Amount_);
            assertEq(bERC20.balanceOf(address(this)), erc20Amount_);

            pearlmit.approve(address(aERC20), 0, address(aTOFT), uint200(erc20Amount_), uint48(block.timestamp + 1)); // Atomic approval
            aERC20.approve(address(pearlmit), uint200(erc20Amount_));
            aTOFT.wrap(address(this), address(this), erc20Amount_);

            pearlmit.approve(address(bERC20), 0, address(bTOFT), uint200(erc20Amount_), uint48(block.timestamp + 1)); // Atomic approval
            bERC20.approve(address(pearlmit), uint200(erc20Amount_));
            bTOFT.wrap(address(this), address(this), erc20Amount_);

            assertEq(aTOFT.balanceOf(address(this)), erc20Amount_);
            assertEq(bTOFT.balanceOf(address(this)), erc20Amount_);

            aTOFT.approve(address(yieldBox), erc20Amount_);
            yieldBox.depositAsset(aTOFTYieldBoxId, address(this), address(singularity), erc20Amount_, 0);
            assertGt(yieldBox.balanceOf(address(singularity), aTOFTYieldBoxId), 0);

            assertEq(aTOFT.balanceOf(address(this)), 0);
            deal(address(aTOFT), address(this), erc20Amount_);
            assertEq(aTOFT.balanceOf(address(this)), erc20Amount_);
        }

        //useful in case of withdraw after borrow
        LZSendParam memory withdrawLzSendParam_;
        MessagingFee memory withdrawMsgFee_; // Will be used as value for the composed msg

        uint256 tokenAmount_ = 0.5 ether;

        {
            // @dev `withdrawMsgFee_` is to be airdropped on dst to pay for the send to source operation (B->A).
            PrepareLzCallReturn memory prepareLzCallReturn1_ = tOFTHelper.prepareLzCall( // B->A data
                ITOFT(address(bTOFT)),
                PrepareLzCallData({
                    dstEid: aEid,
                    recipient: OFTMsgCodec.addressToBytes32(address(this)),
                    amountToSendLD: tokenAmount_,
                    minAmountToCreditLD: tokenAmount_,
                    msgType: SEND,
                    composeMsgData: ComposeMsgData({
                        index: 0,
                        gas: 0,
                        value: 0,
                        data: bytes(""),
                        prevData: bytes(""),
                        prevOptionsData: bytes("")
                    }),
                    lzReceiveGas: 500_000,
                    lzReceiveValue: 0
                })
            );
            withdrawLzSendParam_ = prepareLzCallReturn1_.lzSendParam;
            withdrawMsgFee_ = prepareLzCallReturn1_.msgFee;
        }

        /**
         * Actions
         */
        uint256 tokenAmountSD = tOFTHelper.toSD(tokenAmount_, aTOFT.decimalConversionRate());

        //approve magnetar
        pearlmit.approve(address(bTOFT), 0, address(magnetar), type(uint200).max, uint48(block.timestamp + 1)); // Atomic approval
        bTOFT.approve(address(pearlmit), type(uint200).max);

        MarketBorrowMsg memory marketBorrowMsg = MarketBorrowMsg({
            user: address(this),
            borrowParams: IBorrowParams({
                amount: tokenAmountSD,
                borrowAmount: tokenAmountSD,
                magnetar: address(magnetar),
                marketHelper: address(marketHelper),
                market: address(singularity),
                deposit: true
            }),
            withdrawParams: MagnetarWithdrawData({
                withdraw: true,
                yieldBox: address(yieldBox),
                assetId: aTOFTYieldBoxId,
                unwrap: false,
                lzSendParams: LZSendParam({
                    refundAddress: address(this),
                    fee: MessagingFee({lzTokenFee: 0, nativeFee: 0}),
                    extraOptions: "0x",
                    sendParam: SendParam({
                        amountLD: tokenAmount_,
                        composeMsg: "0x",
                        dstEid: 0,
                        extraOptions: "0x",
                        minAmountLD: 0,
                        oftCmd: "0x",
                        to: OFTMsgCodec.addressToBytes32(address(this))
                    })
                }),
                sendGas: 0,
                composeGas: 0,
                sendVal: 0,
                composeVal: 0,
                composeMsg: "0x",
                composeMsgType: 0
            })
        });
        bytes memory marketBorrowMsg_ = tOFTHelper.buildMarketBorrowMsg(marketBorrowMsg);

        PrepareLzCallReturn memory prepareLzCallReturn2_ = tOFTHelper.prepareLzCall(
            ITOFT(address(aTOFT)),
            PrepareLzCallData({
                dstEid: bEid,
                recipient: OFTMsgCodec.addressToBytes32(address(this)),
                amountToSendLD: tokenAmount_,
                minAmountToCreditLD: tokenAmount_,
                msgType: PT_YB_SEND_SGL_BORROW,
                composeMsgData: ComposeMsgData({
                    index: 0,
                    gas: 1_000_000,
                    value: uint128(withdrawMsgFee_.nativeFee),
                    data: marketBorrowMsg_,
                    prevData: bytes(""),
                    prevOptionsData: bytes("")
                }),
                lzReceiveGas: 1_000_000,
                lzReceiveValue: 0
            })
        );
        bytes memory composeMsg_ = prepareLzCallReturn2_.composeMsg;
        bytes memory oftMsgOptions_ = prepareLzCallReturn2_.oftMsgOptions;
        MessagingFee memory msgFee_ = prepareLzCallReturn2_.msgFee;
        LZSendParam memory lzSendParam_ = prepareLzCallReturn2_.lzSendParam;

        (MessagingReceipt memory msgReceipt_,) = aTOFT.sendPacket{value: msgFee_.nativeFee}(lzSendParam_, composeMsg_);

        {
            verifyPackets(uint32(bEid), address(bTOFT));

            __callLzCompose(
                LzOFTComposedData(
                    PT_YB_SEND_SGL_BORROW,
                    msgReceipt_.guid,
                    composeMsg_,
                    bEid,
                    address(bTOFT), // Compose creator (at lzReceive)
                    address(bTOFT), // Compose receiver (at lzCompose)
                    address(this),
                    oftMsgOptions_
                )
            );
        }

        // Check execution
        {
            assertEq(aTOFT.balanceOf(address(this)), erc20Amount_);
            assertEq(bTOFT.balanceOf(address(this)), erc20Amount_);
            assertEq(yieldBox.toAmount(aTOFTYieldBoxId, yieldBox.balanceOf(address(this), aTOFTYieldBoxId), false), 0);
        }
    }

    function test_market_remove_collateral() public {
        uint256 erc20Amount_ = 1 ether;

        // setup
        {
            deal(address(bTOFT), address(this), erc20Amount_);
            bTOFT.approve(address(yieldBox), type(uint256).max);
            yieldBox.depositAsset(bTOFTYieldBoxId, address(this), address(singularity), erc20Amount_, 0);
        }

        //useful in case of withdraw after borrow
        LZSendParam memory withdrawLzSendParam_;
        MessagingFee memory withdrawMsgFee_; // Will be used as value for the composed msg

        uint256 tokenAmount_ = 0.5 ether;

        {
            // @dev `withdrawMsgFee_` is to be airdropped on dst to pay for the send to source operation (B->A).
            PrepareLzCallReturn memory prepareLzCallReturn1_ = tOFTHelper.prepareLzCall( // B->A data
                ITOFT(address(bTOFT)),
                PrepareLzCallData({
                    dstEid: aEid,
                    recipient: OFTMsgCodec.addressToBytes32(address(this)),
                    amountToSendLD: 0,
                    minAmountToCreditLD: 0,
                    msgType: SEND,
                    composeMsgData: ComposeMsgData({
                        index: 0,
                        gas: 0,
                        value: 0,
                        data: bytes(""),
                        prevData: bytes(""),
                        prevOptionsData: bytes("")
                    }),
                    lzReceiveGas: 500_000,
                    lzReceiveValue: 0
                })
            );
            withdrawLzSendParam_ = prepareLzCallReturn1_.lzSendParam;
            withdrawMsgFee_ = prepareLzCallReturn1_.msgFee;
        }

        /**
         * Actions
         */
        uint256 tokenAmountSD = tOFTHelper.toSD(tokenAmount_, aTOFT.decimalConversionRate());

        //approve magnetar
        bTOFT.approve(address(magnetar), type(uint256).max);
        MarketRemoveCollateralMsg memory marketMsg = MarketRemoveCollateralMsg({
            user: address(this),
            removeParams: IRemoveParams({
                amount: tokenAmountSD,
                magnetar: address(magnetar),
                marketHelper: address(marketHelper),
                market: address(singularity)
            }),
            withdrawParams: MagnetarWithdrawData({
                withdraw: true,
                yieldBox: address(yieldBox),
                assetId: bTOFTYieldBoxId,
                unwrap: false,
                lzSendParams: LZSendParam({
                    refundAddress: address(this),
                    fee: MessagingFee({lzTokenFee: 0, nativeFee: 0}),
                    extraOptions: "0x",
                    sendParam: SendParam({
                        amountLD: tokenAmount_,
                        composeMsg: "0x",
                        dstEid: 0,
                        extraOptions: "0x",
                        minAmountLD: 0,
                        oftCmd: "0x",
                        to: OFTMsgCodec.addressToBytes32(address(this))
                    })
                }),
                sendGas: 0,
                composeGas: 0,
                sendVal: 0,
                composeVal: 0,
                composeMsg: "0x",
                composeMsgType: 0
            })
        });
        bytes memory marketMsg_ = tOFTHelper.buildMarketRemoveCollateralMsg(marketMsg);

        PrepareLzCallReturn memory prepareLzCallReturn2_ = tOFTHelper.prepareLzCall(
            ITOFT(address(aTOFT)),
            PrepareLzCallData({
                dstEid: bEid,
                recipient: OFTMsgCodec.addressToBytes32(address(this)),
                amountToSendLD: 0,
                minAmountToCreditLD: 0,
                msgType: PT_MARKET_REMOVE_COLLATERAL,
                composeMsgData: ComposeMsgData({
                    index: 0,
                    gas: 500_000,
                    value: uint128(withdrawMsgFee_.nativeFee),
                    data: marketMsg_,
                    prevData: bytes(""),
                    prevOptionsData: bytes("")
                }),
                lzReceiveGas: 500_000,
                lzReceiveValue: 0
            })
        );
        bytes memory composeMsg_ = prepareLzCallReturn2_.composeMsg;
        bytes memory oftMsgOptions_ = prepareLzCallReturn2_.oftMsgOptions;
        MessagingFee memory msgFee_ = prepareLzCallReturn2_.msgFee;
        LZSendParam memory lzSendParam_ = prepareLzCallReturn2_.lzSendParam;

        (MessagingReceipt memory msgReceipt_,) = aTOFT.sendPacket{value: msgFee_.nativeFee}(lzSendParam_, composeMsg_);

        {
            verifyPackets(uint32(bEid), address(bTOFT));

            __callLzCompose(
                LzOFTComposedData(
                    PT_MARKET_REMOVE_COLLATERAL,
                    msgReceipt_.guid,
                    composeMsg_,
                    bEid,
                    address(bTOFT), // Compose creator (at lzReceive)
                    address(bTOFT), // Compose receiver (at lzCompose)
                    address(this),
                    oftMsgOptions_
                )
            );
        }

        // Check execution
        {
            assertEq(bTOFT.balanceOf(address(this)), tokenAmount_);
            assertEq(yieldBox.toAmount(bTOFTYieldBoxId, yieldBox.balanceOf(address(this), bTOFTYieldBoxId), false), 0);
        }
    }

    function test_receive_with_params() public {
        uint256 erc20Amount_ = 1 ether;

        //setup
        {
            deal(address(aTOFT), address(this), erc20Amount_);

            // assure unwrap liquidity
            deal(address(bERC20), address(this), erc20Amount_);
            assertEq(bERC20.balanceOf(address(this)), erc20Amount_);

            pearlmit.approve(address(bERC20), 0, address(bTOFT), uint200(erc20Amount_), uint48(block.timestamp + 1)); // Atomic approval
            bERC20.approve(address(pearlmit), uint200(erc20Amount_));
            bTOFT.wrap(address(this), address(this), erc20Amount_);
            assertEq(bTOFT.balanceOf(address(this)), erc20Amount_);
            assertEq(bERC20.balanceOf(address(bTOFT.vault())), erc20Amount_);
        }

        //useful in case of withdraw after borrow
        LZSendParam memory withdrawLzSendParam_;
        MessagingFee memory withdrawMsgFee_; // Will be used as value for the composed msg

        {
            // @dev `withdrawMsgFee_` is to be airdropped on dst to pay for the send to source operation (B->A).
            PrepareLzCallReturn memory prepareLzCallReturn1_ = tOFTHelper.prepareLzCall( // B->A data
                ITOFT(address(bTOFT)),
                PrepareLzCallData({
                    dstEid: aEid,
                    recipient: OFTMsgCodec.addressToBytes32(address(this)),
                    amountToSendLD: erc20Amount_,
                    minAmountToCreditLD: erc20Amount_,
                    msgType: SEND,
                    composeMsgData: ComposeMsgData({
                        index: 0,
                        gas: 0,
                        value: 0,
                        data: bytes(""),
                        prevData: bytes(""),
                        prevOptionsData: bytes("")
                    }),
                    lzReceiveGas: 500_000,
                    lzReceiveValue: 0
                })
            );
            withdrawLzSendParam_ = prepareLzCallReturn1_.lzSendParam;
            withdrawMsgFee_ = prepareLzCallReturn1_.msgFee;
        }

        /**
         * Actions
         */
        uint256 tokenAmountSD = tOFTHelper.toSD(erc20Amount_, aTOFT.decimalConversionRate());

        //approve magnetar
        SendParamsMsg memory sendMsg = SendParamsMsg({receiver: address(this), unwrap: true, amount: tokenAmountSD});
        bytes memory sendMsg_ = tOFTHelper.buildSendWithParamsMsg(sendMsg);

        PrepareLzCallReturn memory prepareLzCallReturn2_ = tOFTHelper.prepareLzCall(
            ITOFT(address(aTOFT)),
            PrepareLzCallData({
                dstEid: bEid,
                recipient: OFTMsgCodec.addressToBytes32(address(this)),
                amountToSendLD: erc20Amount_,
                minAmountToCreditLD: erc20Amount_,
                msgType: PT_SEND_PARAMS,
                composeMsgData: ComposeMsgData({
                    index: 0,
                    gas: 500_000,
                    value: uint128(withdrawMsgFee_.nativeFee),
                    data: sendMsg_,
                    prevData: bytes(""),
                    prevOptionsData: bytes("")
                }),
                lzReceiveGas: 500_000,
                lzReceiveValue: 0
            })
        );
        bytes memory composeMsg_ = prepareLzCallReturn2_.composeMsg;
        bytes memory oftMsgOptions_ = prepareLzCallReturn2_.oftMsgOptions;
        MessagingFee memory msgFee_ = prepareLzCallReturn2_.msgFee;
        LZSendParam memory lzSendParam_ = prepareLzCallReturn2_.lzSendParam;

        (MessagingReceipt memory msgReceipt_,) = aTOFT.sendPacket{value: msgFee_.nativeFee}(lzSendParam_, composeMsg_);

        {
            verifyPackets(uint32(bEid), address(bTOFT));

            __callLzCompose(
                LzOFTComposedData(
                    PT_SEND_PARAMS,
                    msgReceipt_.guid,
                    composeMsg_,
                    bEid,
                    address(bTOFT), // Compose creator (at lzReceive)
                    address(bTOFT), // Compose receiver (at lzCompose)
                    address(this),
                    oftMsgOptions_
                )
            );
        }

        // Check execution
        {
            assertEq(bERC20.balanceOf(address(this)), erc20Amount_);
        }
    }

    function test_reaaaaaceive_with_params_userA() public {
        uint256 erc20Amount_ = 1 ether;

        //setup
        {
            deal(address(aTOFT), address(this), erc20Amount_);

            // assure unwrap liquidity
            deal(address(bERC20), address(this), erc20Amount_);
            assertEq(bERC20.balanceOf(address(this)), erc20Amount_);

            pearlmit.approve(address(bERC20), 0, address(bTOFT), uint200(erc20Amount_), uint48(block.timestamp + 1)); // Atomic approval
            bERC20.approve(address(pearlmit), uint200(erc20Amount_));
            bTOFT.wrap(address(this), address(this), erc20Amount_);
            assertEq(bTOFT.balanceOf(address(this)), erc20Amount_);
        }

        //useful in case of withdraw after borrow
        LZSendParam memory withdrawLzSendParam_;
        MessagingFee memory withdrawMsgFee_; // Will be used as value for the composed msg

        {
            // @dev `withdrawMsgFee_` is to be airdropped on dst to pay for the send to source operation (B->A).
            PrepareLzCallReturn memory prepareLzCallReturn1_ = tOFTHelper.prepareLzCall( // B->A data
                ITOFT(address(bTOFT)),
                PrepareLzCallData({
                    dstEid: aEid,
                    recipient: OFTMsgCodec.addressToBytes32(address(userA)),
                    amountToSendLD: erc20Amount_,
                    minAmountToCreditLD: erc20Amount_,
                    msgType: SEND,
                    composeMsgData: ComposeMsgData({
                        index: 0,
                        gas: 0,
                        value: 0,
                        data: bytes(""),
                        prevData: bytes(""),
                        prevOptionsData: bytes("")
                    }),
                    lzReceiveGas: 500_000,
                    lzReceiveValue: 0
                })
            );
            withdrawLzSendParam_ = prepareLzCallReturn1_.lzSendParam;
            withdrawMsgFee_ = prepareLzCallReturn1_.msgFee;
        }

        /**
         * Actions
         */
        uint256 tokenAmountSD = tOFTHelper.toSD(erc20Amount_, aTOFT.decimalConversionRate());

        //approve magnetar
        SendParamsMsg memory sendMsg = SendParamsMsg({receiver: address(userA), unwrap: true, amount: tokenAmountSD});
        bytes memory sendMsg_ = tOFTHelper.buildSendWithParamsMsg(sendMsg);

        PrepareLzCallReturn memory prepareLzCallReturn2_ = tOFTHelper.prepareLzCall(
            ITOFT(address(aTOFT)),
            PrepareLzCallData({
                dstEid: bEid,
                recipient: OFTMsgCodec.addressToBytes32(address(userA)),
                amountToSendLD: erc20Amount_,
                minAmountToCreditLD: erc20Amount_,
                msgType: PT_SEND_PARAMS,
                composeMsgData: ComposeMsgData({
                    index: 0,
                    gas: 500_000,
                    value: uint128(withdrawMsgFee_.nativeFee),
                    data: sendMsg_,
                    prevData: bytes(""),
                    prevOptionsData: bytes("")
                }),
                lzReceiveGas: 500_000,
                lzReceiveValue: 0
            })
        );
        bytes memory composeMsg_ = prepareLzCallReturn2_.composeMsg;
        bytes memory oftMsgOptions_ = prepareLzCallReturn2_.oftMsgOptions;
        MessagingFee memory msgFee_ = prepareLzCallReturn2_.msgFee;
        LZSendParam memory lzSendParam_ = prepareLzCallReturn2_.lzSendParam;

        (MessagingReceipt memory msgReceipt_,) = aTOFT.sendPacket{value: msgFee_.nativeFee}(lzSendParam_, composeMsg_);

        {
            verifyPackets(uint32(bEid), address(bTOFT));

            // approve address(this) to allow `transferFrom(userA, address(this)) in lzCompose receiver
            vm.prank(address(userA));
            bTOFT.approve(address(this), erc20Amount_);

            __callLzCompose(
                LzOFTComposedData(
                    PT_SEND_PARAMS,
                    msgReceipt_.guid,
                    composeMsg_,
                    bEid,
                    address(bTOFT), // Compose creator (at lzReceive)
                    address(bTOFT), // Compose receiver (at lzCompose)
                    address(this),
                    oftMsgOptions_
                )
            );
        }

        // Check execution
        {
            assertEq(bERC20.balanceOf(address(userA)), erc20Amount_);
        }
    }

    function test_exercise_option() public {
        uint256 erc20Amount_ = 1 ether;

        //setup
        {
            deal(address(aTOFT), address(this), erc20Amount_);

            // @dev send TAP to tOB
            deal(address(tapOFT), address(tOB), erc20Amount_);

            // @dev set `paymentTokenAmount` on `tOB`
            tOB.setPaymentTokenAmount(erc20Amount_);
        }

        //useful in case of withdraw after borrow
        LZSendParam memory withdrawLzSendParam_;
        MessagingFee memory withdrawMsgFee_; // Will be used as value for the composed msg

        pearlmit.approve(address(bTOFT), 0, address(tOB), type(uint200).max, uint48(block.timestamp + 1));

        {
            // @dev `withdrawMsgFee_` is to be airdropped on dst to pay for the send to source operation (B->A).
            PrepareLzCallReturn memory prepareLzCallReturn1_ = tOFTHelper.prepareLzCall( // B->A data
                ITOFT(address(bTOFT)),
                PrepareLzCallData({
                    dstEid: aEid,
                    recipient: OFTMsgCodec.addressToBytes32(address(this)),
                    amountToSendLD: erc20Amount_,
                    minAmountToCreditLD: erc20Amount_,
                    msgType: SEND,
                    composeMsgData: ComposeMsgData({
                        index: 0,
                        gas: 0,
                        value: 0,
                        data: bytes(""),
                        prevData: bytes(""),
                        prevOptionsData: bytes("")
                    }),
                    lzReceiveGas: 500_000,
                    lzReceiveValue: 0
                })
            );
            withdrawLzSendParam_ = prepareLzCallReturn1_.lzSendParam;
            withdrawMsgFee_ = prepareLzCallReturn1_.msgFee;
        }

        /**
         * Actions
         */
        uint256 tokenAmountSD = tOFTHelper.toSD(erc20Amount_, aTOFT.decimalConversionRate());

        //approve magnetar
        ExerciseOptionsMsg memory exerciseMsg = ExerciseOptionsMsg({
            optionsData: IExerciseOptionsData({
                from: address(this),
                target: address(tOB),
                paymentTokenAmount: tokenAmountSD,
                oTAPTokenID: 0, // @dev ignored in TapiocaOptionsBrokerMock
                tapAmount: tokenAmountSD
            }),
            withdrawOnOtherChain: false,
            lzSendParams: LZSendParam({
                sendParam: SendParam({
                    dstEid: 0,
                    to: "0x",
                    amountLD: 0,
                    minAmountLD: 0,
                    extraOptions: "0x",
                    composeMsg: "0x",
                    oftCmd: "0x"
                }),
                fee: MessagingFee({nativeFee: 0, lzTokenFee: 0}),
                extraOptions: "0x",
                refundAddress: address(this)
            }),
            composeMsg: "0x"
        });
        bytes memory sendMsg_ = tOFTHelper.buildExerciseOptionMsg(exerciseMsg);

        PrepareLzCallReturn memory prepareLzCallReturn2_ = tOFTHelper.prepareLzCall(
            ITOFT(address(aTOFT)),
            PrepareLzCallData({
                dstEid: bEid,
                recipient: OFTMsgCodec.addressToBytes32(address(this)),
                amountToSendLD: erc20Amount_,
                minAmountToCreditLD: erc20Amount_,
                msgType: PT_TAP_EXERCISE,
                composeMsgData: ComposeMsgData({
                    index: 0,
                    gas: 500_000,
                    value: uint128(withdrawMsgFee_.nativeFee),
                    data: sendMsg_,
                    prevData: bytes(""),
                    prevOptionsData: bytes("")
                }),
                lzReceiveGas: 500_000,
                lzReceiveValue: 0
            })
        );
        bytes memory composeMsg_ = prepareLzCallReturn2_.composeMsg;
        bytes memory oftMsgOptions_ = prepareLzCallReturn2_.oftMsgOptions;
        MessagingFee memory msgFee_ = prepareLzCallReturn2_.msgFee;
        LZSendParam memory lzSendParam_ = prepareLzCallReturn2_.lzSendParam;

        (MessagingReceipt memory msgReceipt_,) = aTOFT.sendPacket{value: msgFee_.nativeFee}(lzSendParam_, composeMsg_);

        {
            verifyPackets(uint32(bEid), address(bTOFT));

            __callLzCompose(
                LzOFTComposedData(
                    PT_TAP_EXERCISE,
                    msgReceipt_.guid,
                    composeMsg_,
                    bEid,
                    address(bTOFT), // Compose creator (at lzReceive)
                    address(bTOFT), // Compose receiver (at lzCompose)
                    address(this),
                    oftMsgOptions_
                )
            );
        }

        // Check execution
        {
            // @dev TapiocaOptionsBrokerMock uses 90% of msg.options.paymentTokenAmount
            // @dev we check for the rest (10%) if it was returned
            assertEq(bTOFT.balanceOf(address(this)), erc20Amount_ * 1e4 / 1e5);

            assertEq(tapOFT.balanceOf(address(this)), erc20Amount_);
        }
    }

    function test_tOFT_yb_permit_all() public {
        bytes memory approvalMsg_;
        {
            ERC20PermitStruct memory approvalUserB_ =
                ERC20PermitStruct({owner: userA, spender: userB, value: 0, nonce: 0, deadline: 1 days});

            bytes32 digest_ = _getYieldBoxPermitAllTypedDataHash(approvalUserB_);
            YieldBoxApproveAllMsg memory permitApproval_ =
                __getYieldBoxPermitAllData(approvalUserB_, address(yieldBox), true, digest_, userAPKey);

            approvalMsg_ = tOFTHelper.buildYieldBoxApproveAllMsg(permitApproval_);
        }

        PrepareLzCallReturn memory prepareLzCallReturn_ = tOFTHelper.prepareLzCall(
            ITOFT(address(aTOFT)),
            PrepareLzCallData({
                dstEid: bEid,
                recipient: OFTMsgCodec.addressToBytes32(address(this)),
                amountToSendLD: 0,
                minAmountToCreditLD: 0,
                msgType: PT_YB_APPROVE_ALL,
                composeMsgData: ComposeMsgData({
                    index: 0,
                    gas: 1_000_000,
                    value: 0,
                    data: approvalMsg_,
                    prevData: bytes(""),
                    prevOptionsData: bytes("")
                }),
                lzReceiveGas: 1_000_000,
                lzReceiveValue: 0
            })
        );
        bytes memory composeMsg_ = prepareLzCallReturn_.composeMsg;
        bytes memory oftMsgOptions_ = prepareLzCallReturn_.oftMsgOptions;
        MessagingFee memory msgFee_ = prepareLzCallReturn_.msgFee;
        LZSendParam memory lzSendParam_ = prepareLzCallReturn_.lzSendParam;

        assertEq(yieldBox.isApprovedForAll(address(userA), address(userB)), false);

        (MessagingReceipt memory msgReceipt_,) = aTOFT.sendPacket{value: msgFee_.nativeFee}(lzSendParam_, composeMsg_);

        verifyPackets(uint32(bEid), address(bTOFT));

        __callLzCompose(
            LzOFTComposedData(
                PT_YB_APPROVE_ALL,
                msgReceipt_.guid,
                composeMsg_,
                bEid,
                address(bTOFT), // Compose creator (at lzReceive)
                address(bTOFT), // Compose receiver (at lzCompose)
                address(this),
                oftMsgOptions_
            )
        );

        assertEq(yieldBox.isApprovedForAll(address(userA), address(userB)), true);
        assertEq(yieldBox.isApprovedForAll(address(userA), address(this)), false);
    }

    function test_tOFT_yb_revoke_all() public {
        bytes memory approvalMsg_;
        {
            ERC20PermitStruct memory approvalUserB_ =
                ERC20PermitStruct({owner: userA, spender: userB, value: 0, nonce: 0, deadline: 1 days});

            bytes32 digest_ = _getYieldBoxPermitAllTypedDataHash(approvalUserB_);
            YieldBoxApproveAllMsg memory permitApproval_ =
                __getYieldBoxPermitAllData(approvalUserB_, address(yieldBox), false, digest_, userAPKey);

            approvalMsg_ = tOFTHelper.buildYieldBoxApproveAllMsg(permitApproval_);
        }

        PrepareLzCallReturn memory prepareLzCallReturn_ = tOFTHelper.prepareLzCall(
            ITOFT(address(aTOFT)),
            PrepareLzCallData({
                dstEid: bEid,
                recipient: OFTMsgCodec.addressToBytes32(address(this)),
                amountToSendLD: 0,
                minAmountToCreditLD: 0,
                msgType: PT_YB_APPROVE_ALL,
                composeMsgData: ComposeMsgData({
                    index: 0,
                    gas: 1_000_000,
                    value: 0,
                    data: approvalMsg_,
                    prevData: bytes(""),
                    prevOptionsData: bytes("")
                }),
                lzReceiveGas: 1_000_000,
                lzReceiveValue: 0
            })
        );
        bytes memory composeMsg_ = prepareLzCallReturn_.composeMsg;
        bytes memory oftMsgOptions_ = prepareLzCallReturn_.oftMsgOptions;
        MessagingFee memory msgFee_ = prepareLzCallReturn_.msgFee;
        LZSendParam memory lzSendParam_ = prepareLzCallReturn_.lzSendParam;

        vm.prank(address(userA));
        yieldBox.setApprovalForAll(address(userB), true);
        assertEq(yieldBox.isApprovedForAll(address(userA), address(userB)), true);

        (MessagingReceipt memory msgReceipt_,) = aTOFT.sendPacket{value: msgFee_.nativeFee}(lzSendParam_, composeMsg_);

        verifyPackets(uint32(bEid), address(bTOFT));

        __callLzCompose(
            LzOFTComposedData(
                PT_YB_APPROVE_ALL,
                msgReceipt_.guid,
                composeMsg_,
                bEid,
                address(bTOFT), // Compose creator (at lzReceive)
                address(bTOFT), // Compose receiver (at lzCompose)
                address(this),
                oftMsgOptions_
            )
        );

        assertEq(yieldBox.isApprovedForAll(address(userA), address(userB)), false);
    }

    function test_tOFT_yb_permit_asset() public {
        YieldBoxApproveAssetMsg memory permitApprovalB_;
        YieldBoxApproveAssetMsg memory permitApprovalC_;
        bytes memory approvalsMsg_;

        {
            ERC20PermitStruct memory approvalUserB_ =
                ERC20PermitStruct({owner: userA, spender: userB, value: aTOFTYieldBoxId, nonce: 0, deadline: 1 days});
            ERC20PermitStruct memory approvalUserC_ = ERC20PermitStruct({
                owner: userA,
                spender: address(this),
                value: bTOFTYieldBoxId,
                nonce: 1, // Nonce is 1 because we already called permit() on userB
                deadline: 2 days
            });

            permitApprovalB_ = __getYieldBoxPermitAssetData(
                approvalUserB_, address(yieldBox), true, _getYieldBoxPermitAssetTypedDataHash(approvalUserB_), userAPKey
            );

            permitApprovalC_ = __getYieldBoxPermitAssetData(
                approvalUserC_, address(yieldBox), true, _getYieldBoxPermitAssetTypedDataHash(approvalUserC_), userAPKey
            );

            YieldBoxApproveAssetMsg[] memory approvals_ = new YieldBoxApproveAssetMsg[](2);
            approvals_[0] = permitApprovalB_;
            approvals_[1] = permitApprovalC_;

            approvalsMsg_ = tOFTHelper.buildYieldBoxApproveAssetMsg(approvals_);
        }

        PrepareLzCallReturn memory prepareLzCallReturn_ = tOFTHelper.prepareLzCall(
            ITOFT(address(aTOFT)),
            PrepareLzCallData({
                dstEid: bEid,
                recipient: OFTMsgCodec.addressToBytes32(address(this)),
                amountToSendLD: 0,
                minAmountToCreditLD: 0,
                msgType: PT_YB_APPROVE_ASSET,
                composeMsgData: ComposeMsgData({
                    index: 0,
                    gas: 1_000_000,
                    value: 0,
                    data: approvalsMsg_,
                    prevData: bytes(""),
                    prevOptionsData: bytes("")
                }),
                lzReceiveGas: 1_000_000,
                lzReceiveValue: 0
            })
        );
        bytes memory composeMsg_ = prepareLzCallReturn_.composeMsg;
        bytes memory oftMsgOptions_ = prepareLzCallReturn_.oftMsgOptions;
        MessagingFee memory msgFee_ = prepareLzCallReturn_.msgFee;
        LZSendParam memory lzSendParam_ = prepareLzCallReturn_.lzSendParam;

        assertEq(yieldBox.isApprovedForAsset(address(userA), address(userB), aTOFTYieldBoxId), false);
        assertEq(yieldBox.isApprovedForAsset(address(userA), address(this), bTOFTYieldBoxId), false);

        (MessagingReceipt memory msgReceipt_,) = aTOFT.sendPacket{value: msgFee_.nativeFee}(lzSendParam_, composeMsg_);

        verifyPackets(uint32(bEid), address(bTOFT));

        __callLzCompose(
            LzOFTComposedData(
                PT_YB_APPROVE_ASSET,
                msgReceipt_.guid,
                composeMsg_,
                bEid,
                address(bTOFT), // Compose creator (at lzReceive)
                address(bTOFT), // Compose receiver (at lzCompose)
                address(this),
                oftMsgOptions_
            )
        );

        assertEq(yieldBox.isApprovedForAsset(address(userA), address(userB), aTOFTYieldBoxId), true);
        assertEq(yieldBox.isApprovedForAsset(address(userA), address(this), bTOFTYieldBoxId), true);
    }

    function test_tOFT_yb_revoke_asset() public {
        YieldBoxApproveAssetMsg memory permitApprovalB_;
        YieldBoxApproveAssetMsg memory permitApprovalC_;
        bytes memory approvalsMsg_;

        {
            ERC20PermitStruct memory approvalUserB_ =
                ERC20PermitStruct({owner: userA, spender: userB, value: aTOFTYieldBoxId, nonce: 0, deadline: 1 days});
            ERC20PermitStruct memory approvalUserC_ = ERC20PermitStruct({
                owner: userA,
                spender: address(this),
                value: bTOFTYieldBoxId,
                nonce: 1, // Nonce is 1 because we already called permit() on userB
                deadline: 2 days
            });

            permitApprovalB_ = __getYieldBoxPermitAssetData(
                approvalUserB_,
                address(yieldBox),
                false,
                _getYieldBoxPermitAssetTypedDataHash(approvalUserB_),
                userAPKey
            );

            permitApprovalC_ = __getYieldBoxPermitAssetData(
                approvalUserC_,
                address(yieldBox),
                false,
                _getYieldBoxPermitAssetTypedDataHash(approvalUserC_),
                userAPKey
            );

            YieldBoxApproveAssetMsg[] memory approvals_ = new YieldBoxApproveAssetMsg[](2);
            approvals_[0] = permitApprovalB_;
            approvals_[1] = permitApprovalC_;

            approvalsMsg_ = tOFTHelper.buildYieldBoxApproveAssetMsg(approvals_);
        }

        PrepareLzCallReturn memory prepareLzCallReturn_ = tOFTHelper.prepareLzCall(
            ITOFT(address(aTOFT)),
            PrepareLzCallData({
                dstEid: bEid,
                recipient: OFTMsgCodec.addressToBytes32(address(this)),
                amountToSendLD: 0,
                minAmountToCreditLD: 0,
                msgType: PT_YB_APPROVE_ASSET,
                composeMsgData: ComposeMsgData({
                    index: 0,
                    gas: 1_000_000,
                    value: 0,
                    data: approvalsMsg_,
                    prevData: bytes(""),
                    prevOptionsData: bytes("")
                }),
                lzReceiveGas: 1_000_000,
                lzReceiveValue: 0
            })
        );
        bytes memory composeMsg_ = prepareLzCallReturn_.composeMsg;
        bytes memory oftMsgOptions_ = prepareLzCallReturn_.oftMsgOptions;
        MessagingFee memory msgFee_ = prepareLzCallReturn_.msgFee;
        LZSendParam memory lzSendParam_ = prepareLzCallReturn_.lzSendParam;

        vm.prank(address(userA));
        yieldBox.setApprovalForAsset(address(userB), aTOFTYieldBoxId, true);
        vm.prank(address(userA));
        yieldBox.setApprovalForAsset(address(this), bTOFTYieldBoxId, true);
        assertEq(yieldBox.isApprovedForAsset(address(userA), address(userB), aTOFTYieldBoxId), true);
        assertEq(yieldBox.isApprovedForAsset(address(userA), address(this), bTOFTYieldBoxId), true);

        (MessagingReceipt memory msgReceipt_,) = aTOFT.sendPacket{value: msgFee_.nativeFee}(lzSendParam_, composeMsg_);

        verifyPackets(uint32(bEid), address(bTOFT));

        __callLzCompose(
            LzOFTComposedData(
                PT_YB_APPROVE_ASSET,
                msgReceipt_.guid,
                composeMsg_,
                bEid,
                address(bTOFT), // Compose creator (at lzReceive)
                address(bTOFT), // Compose receiver (at lzCompose)
                address(this),
                oftMsgOptions_
            )
        );

        assertEq(yieldBox.isApprovedForAsset(address(userA), address(userB), aTOFTYieldBoxId), false);
        assertEq(yieldBox.isApprovedForAsset(address(userA), address(this), bTOFTYieldBoxId), false);
    }

    function test_tOFT_market_permit_asset() public {
        bytes memory approvalMsg_;
        {
            // @dev v,r,s will be completed on `__getMarketPermitData`
            MarketPermitActionMsg memory approvalUserB_ = MarketPermitActionMsg({
                target: address(singularity),
                owner: userA,
                spender: userB,
                value: 1e18,
                deadline: 1 days,
                v: 0,
                r: 0,
                s: 0,
                permitAsset: true
            });

            bytes32 digest_ = _getMarketPermitTypedDataHash(true, userA, userB, 1e18, 1 days);
            MarketPermitActionMsg memory permitApproval_ = __getMarketPermitData(approvalUserB_, digest_, userAPKey);

            approvalMsg_ = tOFTHelper.buildMarketPermitApprovalMsg(permitApproval_);
        }

        PrepareLzCallReturn memory prepareLzCallReturn_ = tOFTHelper.prepareLzCall(
            ITOFT(address(aTOFT)),
            PrepareLzCallData({
                dstEid: bEid,
                recipient: OFTMsgCodec.addressToBytes32(address(this)),
                amountToSendLD: 0,
                minAmountToCreditLD: 0,
                msgType: PT_MARKET_PERMIT,
                composeMsgData: ComposeMsgData({
                    index: 0,
                    gas: 1_000_000,
                    value: 0,
                    data: approvalMsg_,
                    prevData: bytes(""),
                    prevOptionsData: bytes("")
                }),
                lzReceiveGas: 1_000_000,
                lzReceiveValue: 0
            })
        );
        bytes memory composeMsg_ = prepareLzCallReturn_.composeMsg;
        bytes memory oftMsgOptions_ = prepareLzCallReturn_.oftMsgOptions;
        MessagingFee memory msgFee_ = prepareLzCallReturn_.msgFee;
        LZSendParam memory lzSendParam_ = prepareLzCallReturn_.lzSendParam;

        (MessagingReceipt memory msgReceipt_,) = aTOFT.sendPacket{value: msgFee_.nativeFee}(lzSendParam_, composeMsg_);

        verifyPackets(uint32(bEid), address(bTOFT));

        __callLzCompose(
            LzOFTComposedData(
                PT_MARKET_PERMIT,
                msgReceipt_.guid,
                composeMsg_,
                bEid,
                address(bTOFT), // Compose creator (at lzReceive)
                address(bTOFT), // Compose receiver (at lzCompose)
                address(this),
                oftMsgOptions_
            )
        );

        assertEq(singularity.allowance(userA, userB), 1e18);
    }

    function test_tOFT_market_permit_collateral() public {
        bytes memory approvalMsg_;
        {
            // @dev v,r,s will be completed on `__getMarketPermitData`
            MarketPermitActionMsg memory approvalUserB_ = MarketPermitActionMsg({
                target: address(singularity),
                owner: userA,
                spender: userB,
                value: 1e18,
                deadline: 1 days,
                v: 0,
                r: 0,
                s: 0,
                permitAsset: false
            });

            bytes32 digest_ = _getMarketPermitTypedDataHash(false, userA, userB, 1e18, 1 days);
            MarketPermitActionMsg memory permitApproval_ = __getMarketPermitData(approvalUserB_, digest_, userAPKey);

            approvalMsg_ = tOFTHelper.buildMarketPermitApprovalMsg(permitApproval_);
        }

        PrepareLzCallReturn memory prepareLzCallReturn_ = tOFTHelper.prepareLzCall(
            ITOFT(address(aTOFT)),
            PrepareLzCallData({
                dstEid: bEid,
                recipient: OFTMsgCodec.addressToBytes32(address(this)),
                amountToSendLD: 0,
                minAmountToCreditLD: 0,
                msgType: PT_MARKET_PERMIT,
                composeMsgData: ComposeMsgData({
                    index: 0,
                    gas: 1_000_000,
                    value: 0,
                    data: approvalMsg_,
                    prevData: bytes(""),
                    prevOptionsData: bytes("")
                }),
                lzReceiveGas: 1_000_000,
                lzReceiveValue: 0
            })
        );
        bytes memory composeMsg_ = prepareLzCallReturn_.composeMsg;
        bytes memory oftMsgOptions_ = prepareLzCallReturn_.oftMsgOptions;
        MessagingFee memory msgFee_ = prepareLzCallReturn_.msgFee;
        LZSendParam memory lzSendParam_ = prepareLzCallReturn_.lzSendParam;

        (MessagingReceipt memory msgReceipt_,) = aTOFT.sendPacket{value: msgFee_.nativeFee}(lzSendParam_, composeMsg_);

        verifyPackets(uint32(bEid), address(bTOFT));

        __callLzCompose(
            LzOFTComposedData(
                PT_MARKET_PERMIT,
                msgReceipt_.guid,
                composeMsg_,
                bEid,
                address(bTOFT), // Compose creator (at lzReceive)
                address(bTOFT), // Compose receiver (at lzCompose)
                address(this),
                oftMsgOptions_
            )
        );

        assertEq(singularity.allowanceBorrow(userA, userB), 1e18);
    }

    function _getMarketPermitTypedDataHash(
        bool permitAsset,
        address owner_,
        address spender_,
        uint256 value_,
        uint256 deadline_
    ) private view returns (bytes32) {
        bytes32 permitTypeHash_ = permitAsset
            ? bytes32(0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9)
            : bytes32(0xe9685ff6d48c617fe4f692c50e602cce27cbad0290beb93cfa77eac43968d58c);

        uint256 nonce = singularity.nonces(owner_);
        bytes32 structHash_ = keccak256(abi.encode(permitTypeHash_, owner_, spender_, value_, nonce++, deadline_));

        return keccak256(abi.encodePacked("\x19\x01", singularity.DOMAIN_SEPARATOR(), structHash_));
    }

    function _getYieldBoxPermitAllTypedDataHash(ERC20PermitStruct memory _permitData) private view returns (bytes32) {
        bytes32 permitTypeHash_ = keccak256("PermitAll(address owner,address spender,uint256 nonce,uint256 deadline)");

        bytes32 structHash_ = keccak256(
            abi.encode(permitTypeHash_, _permitData.owner, _permitData.spender, _permitData.nonce, _permitData.deadline)
        );

        return keccak256(abi.encodePacked("\x19\x01", _getYieldBoxDomainSeparator(), structHash_));
    }

    function _getYieldBoxPermitAssetTypedDataHash(ERC20PermitStruct memory _permitData)
        private
        view
        returns (bytes32)
    {
        bytes32 permitTypeHash_ =
            keccak256("Permit(address owner,address spender,uint256 assetId,uint256 nonce,uint256 deadline)");

        bytes32 structHash_ = keccak256(
            abi.encode(
                permitTypeHash_,
                _permitData.owner,
                _permitData.spender,
                _permitData.value, // @dev this is the assetId
                _permitData.nonce,
                _permitData.deadline
            )
        );

        return keccak256(abi.encodePacked("\x19\x01", _getYieldBoxDomainSeparator(), structHash_));
    }

    function _getYieldBoxDomainSeparator() private view returns (bytes32) {
        bytes32 typeHash =
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
        bytes32 hashedName = keccak256(bytes("YieldBox"));
        bytes32 hashedVersion = keccak256(bytes("1"));
        bytes32 domainSeparator =
            keccak256(abi.encode(typeHash, hashedName, hashedVersion, block.chainid, address(yieldBox)));
        return domainSeparator;
    }
}
