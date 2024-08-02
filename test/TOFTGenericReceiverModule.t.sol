// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {TOFTMsgCodec} from "../contracts/tOFT/libraries/TOFTMsgCodec.sol";
import {SendParamsMsg, TOFTInitStruct} from "tapioca-periph/interfaces/oft/ITOFT.sol";
import {console} from "forge-std/console.sol";
import {TOFTTestHelper} from "./TOFTTestHelper.t.sol";
import {TOFTGenericReceiverModuleMock} from "./LZSetup/mocks/TOFTGenericReceiverModuleMock.sol";
import {Pearlmit, IPearlmit} from "tapioca-periph/pearlmit/Pearlmit.sol";
import {ICluster, Cluster} from "tapioca-periph/Cluster/Cluster.sol";
import {YieldBox} from "yieldbox/YieldBox.sol";
import {ERC20Mock} from "./ERC20Mock.sol";
import {TapiocaOmnichainExtExec} from "tapioca-periph/tapiocaOmnichainEngine/extension/TapiocaOmnichainExtExec.sol";
import {TOFTVault} from "tapiocaz/tOFT/TOFTVault.sol";
import {
    TOFTHelper, PrepareLzCallData, PrepareLzCallReturn, ComposeMsgData
} from "tapiocaz/tOFT/extensions/TOFTHelper.sol";

contract TOFTGenericReceiverModuleTest is TOFTTestHelper {
    error TOFTGenericReceiverModule_AmountMismatch();

    uint32 aEid = 1;
    uint32 fakeEid = 40; // just a random id to trigger an error in the test
    address __owner = address(this);

    TOFTGenericReceiverModuleMock receiverMockFake; // TOFTGenericReceiverModuleMock with fake endpoint
    TOFTGenericReceiverModuleMock receiverMock; // TOFTGenericReceiverModuleMock
    ERC20Mock aERC20;
    Pearlmit pearlmit;
    YieldBox yieldBox;
    Cluster cluster;
    TapiocaOmnichainExtExec toftExtExec;
    address alice;
    address bob;
    TOFTHelper tOFTHelper;
    TOFTVault aTOFTVault;

    function setUp() public override {
        alice = makeAddr("alice");
        vm.label(alice, "alice");

        tOFTHelper = new TOFTHelper();

        aERC20 = new ERC20Mock("Token A", "TNKA");
        vm.label(address(aERC20), "aERC20");
        setUpEndpoints(3, LibraryType.UltraLightNode);

        pearlmit = new Pearlmit("Pearlmit", "1", address(this), 0);
        yieldBox = createYieldBox(pearlmit, address(this));
        cluster = createCluster(aEid, __owner);
        toftExtExec = new TapiocaOmnichainExtExec();
        aTOFTVault = new TOFTVault(address(aERC20));
        TOFTInitStruct memory _toftInitStruct = TOFTInitStruct({
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

        TOFTInitStruct memory _toftInitStructFake = TOFTInitStruct({
            name: "Token A",
            symbol: "TNKA",
            endpoint: address(endpoints[fakeEid]),
            delegate: __owner,
            yieldBox: address(yieldBox),
            cluster: address(cluster),
            erc20: address(aERC20),
            vault: address(aTOFTVault),
            hostEid: aEid,
            extExec: address(toftExtExec),
            pearlmit: IPearlmit(address(pearlmit))
        });

        receiverMock = new TOFTGenericReceiverModuleMock(_toftInitStruct);
    }

    function test_receiveWithParamsReceiver_unwrapAndTransfer_success() public {
        vm.startPrank(address(receiverMock));
        aTOFTVault.claimOwnership();
        uint64 amount = 1e18;

        vm.startPrank(alice);
        vm.deal(alice, 20 ether);

        uint256 convertedAmount = receiverMock.toLD(amount);
        receiverMock.mint(convertedAmount, alice); //using OTF mint function to mint alice's token
        aERC20.mint(address(aTOFTVault), convertedAmount); //minting the same amount to aTOFTVault
        assertEq(
            receiverMock.balanceOf(alice),
            convertedAmount,
            "Alice's balance should equal the minted amount before transfer"
        );
        assertEq(aERC20.balanceOf(address(alice)), 0, "Alice's balance should be zero before transfer");

        SendParamsMsg memory sendMsg = SendParamsMsg({receiver: alice, unwrap: true, amount: amount});
        bytes memory _data = tOFTHelper.buildSendWithParamsMsg(sendMsg);
        receiverMock.receiveWithParamsReceiver{value: 1 ether}(alice, _data); //transfering tokens from alice to receiverMock
        assertEq(aERC20.balanceOf(address(aTOFTVault)), 0, "aTOFTVault's balance should be zero");
        assertEq(aERC20.balanceOf(alice), convertedAmount, "Alice's balance should be equal to the minted amount");
    }

    function test_receiveWithParamsReceiver_transfer_fail_amountMismatch() public {
        uint256 amount = 1; //random amount
        vm.deal(alice, 20 ether);

        vm.startPrank(alice);
        SendParamsMsg memory sendMsg = SendParamsMsg({receiver: alice, unwrap: false, amount: amount});
        bytes memory _data = tOFTHelper.buildSendWithParamsMsg(sendMsg);
        vm.expectRevert(TOFTGenericReceiverModule_AmountMismatch.selector);
        receiverMock.receiveWithParamsReceiver{value: 1 ether}(alice, _data);
    }
}
