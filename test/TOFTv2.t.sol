// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.22;

// LZ
import {
    SendParam,
    MessagingFee,
    MessagingReceipt,
    OFTReceipt
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OFTComposeMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTComposeMsgCodec.sol";
import {OptionsBuilder} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import {BytesLib} from "solidity-bytes-utils/contracts/BytesLib.sol";
import {Origin} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";

// External
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Tapioca
import {
    ITOFTv2,
    LZSendParam,
    ERC20PermitStruct,
    ERC721PermitStruct,
    ERC20PermitApprovalMsg,
    ERC721PermitApprovalMsg,
    RemoteTransferMsg,
    TOFTInitStruct,
    TOFTModulesInitStruct
} from "../contracts//ITOFTv2.sol";
import {
    TOFTv2Helper,
    PrepareLzCallData,
    PrepareLzCallReturn,
    ComposeMsgData
} from "../contracts/extensions/TOFTv2Helper.sol";
import {TOFTv2MarketReceiverModule} from "../contracts/modules/TOFTv2MarketReceiverModule.sol";
import {YieldBox} from "tapioca-sdk/dist/contracts/YieldBox/contracts/YieldBox.sol";
import {TOFTv2Receiver} from "../contracts/modules/TOFTv2Receiver.sol";
import {TOFTMsgCoder} from "../contracts/libraries/TOFTMsgCoder.sol";
import {TOFTv2Sender} from "../contracts/modules/TOFTv2Sender.sol";
import {Cluster} from "../tapioca-periph/contracts/Cluster/Cluster.sol";

// Tapioca Tests
import {TOFTTestHelper} from "./TOFTTestHelper.t.sol";
import {ERC721Mock} from "./ERC721Mock.sol";
import {TOFTv2Mock} from "./TOFTv2Mock.sol";
import {ERC20Mock} from "./ERC20Mock.sol";

import "forge-std/Test.sol";


contract TOFTv2Test is TOFTTestHelper {
    using OptionsBuilder for bytes;
    using OFTMsgCodec for bytes32;
    using OFTMsgCodec for bytes;

    uint32 aEid = 1;
    uint32 bEid = 2;

    YieldBox yieldBox;
    Cluster cluster;
    ERC20Mock aERC20;
    ERC20Mock bERC20;
    TOFTv2Mock aTOFT;
    TOFTv2Mock bTOFT;

    TOFTv2Helper tOFTv2Helper;

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
    uint16 internal constant PT_REMOTE_TRANSFER = 400; // Use for transferring tokens from the contract from another chain
    uint16 internal constant PT_APPROVALS = 500; // Use for ERC20Permit approvals
    uint16 internal constant PT_NFT_APPROVALS = 501; // Use for ERC721Permit approvals; TODO: check if we need this
    uint16 internal constant PT_YB_APROVE_ASSET = 502; // Use for YieldBox 'setApprovalForAsset(true)' operation
    uint16 internal constant PT_YB_APPROVE_ALL = 503; // Use for YieldBox 'setApprovalForAll(true)' operation
    uint16 internal constant PT_YB_REVOKE_ASSET = 504; // Use for YieldBox 'setApprovalForAsset(false)' operation
    uint16 internal constant PT_YB_REVOKE_ALL = 505; // Use for YieldBox 'setApprovalForAll(false)' operation
    uint16 internal constant PT_MARKET_PERMIT_LEND = 506; // Use for market.permitLend() operation
    uint16 internal constant PT_MARKET_PERMIT_BORROW = 506; // Use for market.permitBorrow() operation
    uint16 internal constant PT_MARKET_REMOVE_COLLATERAL = 700; // Use for remove collateral from a market available on another chain
    uint16 internal constant PT_YB_SEND_SGL_BORROW = 701; // Use fror send to YB and/or borrow from a market available on another chain
    uint16 internal constant PT_LEVERAGE_MARKET_DOWN = 702; // Use for leverage sell on a market available on another chain
    uint16 internal constant PT_TAP_EXERCISE = 703; // Use for exercise options on tOB available on another chain
    uint16 internal constant PT_SEND_PARAMS = 704; // Use for perform a normal OFT send but with a custom payload

     /**
     * @dev TOFTv2 global event checks
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

        setUpEndpoints(3, LibraryType.UltraLightNode);

        yieldBox = createYieldBox();
        cluster = createCluster(address(endpoints[aEid]), __owner);
        
        TOFTInitStruct memory aTOFTInitStruct = createInitStruct("Token A", "TNKA", address(endpoints[aEid]), __owner, address(yieldBox), address(cluster), address(aERC20), aEid);
        TOFTv2Sender aTOFTv2Sender = new TOFTv2Sender(aTOFTInitStruct);
        TOFTv2Receiver aTOFTv2Receiver = new TOFTv2Receiver(aTOFTInitStruct);
        TOFTv2MarketReceiverModule aTOFTv2MarketReceiverModule = new TOFTv2MarketReceiverModule(aTOFTInitStruct);
        TOFTModulesInitStruct memory aTOFTModulesInitStruct = createModulesInitStruct(address(aTOFTv2Sender), address(aTOFTv2Receiver), address(aTOFTv2MarketReceiverModule));
        aTOFT = TOFTv2Mock(
            payable(
                _deployOApp(
                    type(TOFTv2Mock).creationCode,
                    abi.encode(aTOFTInitStruct, aTOFTModulesInitStruct)
                )
            )
        );
        vm.label(address(aTOFT), "aTOFT");

        TOFTInitStruct memory bTOFTInitStruct = createInitStruct("Token B", "TNKB", address(endpoints[bEid]), __owner, address(yieldBox), address(cluster), address(bERC20), bEid);
        TOFTv2Sender bTOFTv2Sender = new TOFTv2Sender(bTOFTInitStruct);
        TOFTv2Receiver bTOFTv2Receiver = new TOFTv2Receiver(bTOFTInitStruct);
        TOFTv2MarketReceiverModule bTOFTv2MarketReceiverModule = new TOFTv2MarketReceiverModule(aTOFTInitStruct);
        TOFTModulesInitStruct memory bTOFTModulesInitStruct = createModulesInitStruct(address(bTOFTv2Sender), address(bTOFTv2Receiver), address(bTOFTv2MarketReceiverModule));
        bTOFT = TOFTv2Mock(
            payable(
                _deployOApp(
                    type(TOFTv2Mock).creationCode,
                    abi.encode(bTOFTInitStruct, bTOFTModulesInitStruct)
                )
            )
        );
        vm.label(address(bTOFT), "bTOFT");

        // config and wire the ofts
        address[] memory ofts = new address[](2);
        ofts[0] = address(aTOFT);
        ofts[1] = address(bTOFT);
        this.wireOApps(ofts);
    }

     function test_constructor() public {
        assertEq(aTOFT.yieldBox(), address(yieldBox));
     }

}