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

