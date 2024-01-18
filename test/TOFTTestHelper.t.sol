// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.22;

// Lz
import {TestHelper} from "./LZSetup/TestHelper.sol";

// Tapioca
import {YieldBoxURIBuilder} from "tapioca-sdk/dist/contracts/YieldBox/contracts/YieldBoxURIBuilder.sol";
import {YieldBox} from "tapioca-sdk/src/contracts/YieldBox/contracts/YieldBox.sol";
import {TOFTInitStruct} from "contracts/ITOFTv2.sol";
import {Cluster} from "@tapioca-periph/Cluster/Cluster.sol";
import {TestUtils} from "./TestUtils.t.sol";

contract TOFTTestHelper.t is TestHelper, TestUtils {
    function createYieldBox() public returns (YieldBox memory) {
        YieldBoxURIBuilder uriBuilder = new YieldBoxURIBuilder();

        return new YieldBox(IWrappedNative(address(0)), uriBuilder);
    }

    function createCluster(address endpoint, address owner) public returns (Cluster memory) {
        return new Cluster(endpoint, owner);
    }

    function createInitStruct(string memory name, string memory symbol, address endpoint, address owner, address yieldBox, address cluster, address erc20, uint256 hostEid) public returns(TOFTInitStruct memory) {
        return TOFTInitStruct(
            {
                name: name,
                symbol: symbol,
                endpoint: endpoint
                owner: owner,
                yieldBox: yieldBox,
                cluster: cluster,
                erc20: aERC20,
                hostEid: aEid
            }
        );
    }

    function createModulesInitStruct(address tOFTSenderModule, address tOFTReceiverModule, address marketReceiverModule) public returns (TOFTModulesInitStruct memory) {
        return TOFTModulesInitStruct(
            {
                tOFTSenderModule: tOFTSenderModule,
                tOFTReceiverModule: tOFTReceiverModule,
                marketReceiverModule: marketReceiverModule
            }
        )
    }

}
