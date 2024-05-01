// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Lz
import {TestHelper} from "./LZSetup/TestHelper.sol";

import {Pearlmit, IPearlmit} from "tapioca-periph/pearlmit/Pearlmit.sol";
import {StargateRouterMock, StargateFactoryMock} from "./StargateRouterMock.sol";
import {Balancer} from "tapiocaz/Balancer.sol";
import {TestUtils} from "./TestUtils.t.sol";

import {ITOFT, TOFTInitStruct, TOFTModulesInitStruct} from "tapioca-periph/interfaces/oft/ITOFT.sol";
import {
    TOFTHelper,
    PrepareLzCallData,
    PrepareLzCallReturn,
    ComposeMsgData
} from "tapiocaz/tOFT/extensions/TOFTHelper.sol";
import {TapiocaOmnichainExtExec} from "tapioca-periph/tapiocaOmnichainEngine/extension/TapiocaOmnichainExtExec.sol";
import {TOFTGenericReceiverModule} from "tapiocaz/tOFT/modules/TOFTGenericReceiverModule.sol";
import {TOFTOptionsReceiverModule} from "tapiocaz/tOFT/modules/TOFTOptionsReceiverModule.sol";
import {TOFTMarketReceiverModule} from "tapiocaz/tOFT/modules/TOFTMarketReceiverModule.sol";
import {ICluster, Cluster} from "tapioca-periph/Cluster/Cluster.sol";
import {TOFTSender} from "tapiocaz/tOFT/modules/TOFTSender.sol";
import {YieldBox} from "yieldbox/YieldBox.sol";

// Tapioca Tests
import {TapiocaOptionsBrokerMock} from "./TapiocaOptionsBrokerMock.sol";
import {mTOFTReceiver} from "tapiocaz/tOFT/modules/mTOFTReceiver.sol";
import {MarketHelperMock} from "./MarketHelperMock.sol";
import {TOFTVault} from "tapiocaz/tOFT/TOFTVault.sol";
import {TOFTTestHelper} from "./TOFTTestHelper.t.sol";
import {SingularityMock} from "./SingularityMock.sol";
import {MagnetarMock} from "./MagnetarMock.sol";
import {mTOFT} from "tapiocaz/tOFT/mTOFT.sol";
import {ERC20Mock} from "./ERC20Mock.sol";
import {TOFTMock} from "./TOFTMock.sol";

import "forge-std/console.sol";

contract TOFTTest is TOFTTestHelper {
    Balancer balancer;
    StargateRouterMock routerA;
    StargateRouterMock routerB;
    StargateFactoryMock factory;

    uint32 aEid = 1;
    uint32 bEid = 2;

    ERC20Mock aERC20;
    ERC20Mock bERC20;
    mTOFT aTOFT;
    mTOFT bTOFT;
    Pearlmit pearlmit;
    YieldBox yieldBox;
    Cluster cluster;
    TOFTHelper tOFTHelper;

    /**
     * DEPLOY setup addresses
     */
    address __endpoint;
    uint256 __hostEid = aEid;
    address __owner = address(this);

    uint256 internal routerEthAPKey = 0x1;
    uint256 internal routerAPKey = 0x2;
    uint256 internal userAAPKey = 0x3;
    address public routerEth = vm.addr(routerEthAPKey);
    address public router = vm.addr(routerAPKey);
    address public userA = vm.addr(userAAPKey);
    uint256 public initialBalance = 100 ether;

    /**
     * @dev Setup the OApps by deploying them and setting up the endpoints.
     */
    function setUp() public override {
        vm.deal(userA, 1000 ether);
        vm.label(routerEth, "routerEth");
        vm.label(router, "router");
        vm.label(userA, "userA");

        aERC20 = new ERC20Mock("Token A", "TNKA");
        bERC20 = new ERC20Mock("Token B", "TNKB");
        vm.label(address(aERC20), "aERC20");
        vm.label(address(bERC20), "bERC20");

        routerA = new StargateRouterMock(aERC20);
        routerB = new StargateRouterMock(bERC20);
        factory = new StargateFactoryMock();
        vm.label(address(routerA), "routerA");
        vm.label(address(routerB), "routerB");
        vm.label(address(factory), "factory");

        setUpEndpoints(3, LibraryType.UltraLightNode);

        balancer = new Balancer(routerEth, address(routerA), address(factory), address(this));
        vm.label(address(balancer), "Balancer");

        pearlmit = new Pearlmit("Pearlmit", "1");
        yieldBox = createYieldBox();
        cluster = createCluster(aEid, __owner);
        pearlmit = new Pearlmit("Pearlmit", "1");

        {
            vm.label(address(endpoints[aEid]), "aEndpoint");
            vm.label(address(endpoints[bEid]), "bEndpoint");
            vm.label(address(yieldBox), "YieldBox");
            vm.label(address(cluster), "Cluster");
        }

        TapiocaOmnichainExtExec toftExtExec = new TapiocaOmnichainExtExec();
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

            aTOFT = mTOFT(
                payable(_deployOApp(type(mTOFT).creationCode, abi.encode(aTOFTInitStruct, aTOFTModulesInitStruct)))
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
            bTOFT = mTOFT(
                payable(_deployOApp(type(mTOFT).creationCode, abi.encode(bTOFTInitStruct, bTOFTModulesInitStruct)))
            );
            vm.label(address(bTOFT), "bTOFT");
        }

        tOFTHelper = new TOFTHelper();
        vm.label(address(tOFTHelper), "TOFTHelper");
    }

    function test_balancer_should_fail_to_init() public {
        // @dev should fail for unauthorized users
        // execute from userA

        vm.startPrank(userA);
        vm.expectRevert("Ownable: caller is not the owner");
        balancer.initConnectedOFT(address(aERC20), 1, address(bERC20), abi.encode(1, 1));
        vm.stopPrank();
    }

    function test_add_connected_chains() public {
        balancer.initConnectedOFT(address(aERC20), 1, address(bERC20), abi.encode(uint256(1), uint256(1)));

        (,, address dstOft,) = balancer.connectedOFTs(address(aERC20), 1);
        assertEq(dstOft, address(bERC20));
    }

    function test_balancer_should_fail_to_rebalance() public {
        vm.startPrank(userA);
        vm.expectRevert();
        balancer.rebalance(payable(address(aERC20)), 1, 1, 1);
        vm.stopPrank();

        vm.expectRevert(Balancer.DestinationNotValid.selector);
        balancer.rebalance(payable(address(aERC20)), 100, 1, 1);
    }

    function test_balancer_rebalance() public {
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
        }

        mTOFT.SetOwnerStateData memory dataA = mTOFT.SetOwnerStateData({
            stargateRouter: address(routerA),
            mintFee: 0,
            mintCap: aTOFT.mintCap(),
            connectedChain: 0,
            connectedChainState: false,
            balancerStateAddress: address(balancer),
            balancerState: true
        });
        aTOFT.setOwnerState(dataA);

        balancer.initConnectedOFT(address(aTOFT), uint16(bEid), address(bTOFT), abi.encode(uint256(1), uint256(1)));
        balancer.addRebalanceAmount(address(aTOFT), uint16(bEid), erc20Amount_);
        balancer.setSgReceiveGas(uint16(aEid), 500_000);
        balancer.setSgReceiveGas(uint16(bEid), 500_000);

        mTOFT.SetOwnerStateData memory dataB = mTOFT.SetOwnerStateData({
            stargateRouter: address(routerA),
            mintFee: 0,
            mintCap: bTOFT.mintCap(),
            connectedChain: 0,
            connectedChainState: false,
            balancerStateAddress: address(0),
            balancerState: false
        });
        bTOFT.setOwnerState(dataB);

        {
            deal(address(aERC20), address(routerB), erc20Amount_);
            deal(address(bERC20), address(bTOFT), erc20Amount_);
        }

        {
            uint256 bERC20BalanceBefore = bERC20.balanceOf(address(bTOFT.vault()));
            balancer.rebalance{value: 1e17}(payable(address(aTOFT)), uint16(bEid), 1e3, erc20Amount_);
            uint256 bERC20BalanceAfter = bERC20.balanceOf(address(bTOFT.vault()));
            assertGt(bERC20BalanceAfter, bERC20BalanceBefore);
        }
    }

    function test_balancer_checker() public {
        bool canExec;
        bytes memory execPayload;
        (canExec, execPayload) = balancer.checker(payable(address(aTOFT)), uint16(bEid), 1e4);
        assertFalse(canExec);

        balancer.initConnectedOFT(address(aTOFT), uint16(bEid), address(bTOFT), abi.encode(1, 1));
        (canExec, execPayload) = balancer.checker(payable(address(aTOFT)), uint16(bEid), 1e4);
        assertFalse(canExec);

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
        }

        balancer.addRebalanceAmount(address(aTOFT), uint16(bEid), erc20Amount_);
        (canExec, execPayload) = balancer.checker(payable(address(aTOFT)), uint16(bEid), 1e4);
        assertTrue(canExec);
    }
}
