// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.22;

// Lz
import {TestHelper} from "./LZSetup/TestHelper.sol";

// Tapioca
// import {MagnetarMarketModule} from "../tapioca-periph/contracts/Magnetar/modules/MagnetarMarketModule.sol";
import {ERC20WithoutStrategy} from "tapioca-sdk/src/contracts/YieldBox/contracts/strategies/ERC20WithoutStrategy.sol";
import {IWrappedNative} from "tapioca-sdk/src/contracts/YieldBox/contracts/interfaces/IWrappedNative.sol";
import {YieldBoxURIBuilder} from "tapioca-sdk/src/contracts/YieldBox/contracts/YieldBoxURIBuilder.sol";
import {TokenType} from "tapioca-sdk/src/contracts/YieldBox/contracts/enums/YieldBoxTokenType.sol";
import {IYieldBox} from "tapioca-sdk/src/contracts/YieldBox/contracts/interfaces/IYieldBox.sol";
import {IStrategy} from "tapioca-sdk/src/contracts/YieldBox/contracts/interfaces/IStrategy.sol";
// import {MagnetarHelper} from "../tapioca-periph/contracts/Magnetar/MagnetarHelper.sol";
// import {MagnetarV2} from "../tapioca-periph/contracts/Magnetar/MagnetarV2.sol";
import {IERC20} from "@boringcrypto/boring-solidity/contracts/interfaces/IERC20.sol";
import {YieldBox} from "tapioca-sdk/src/contracts/YieldBox/contracts/YieldBox.sol";
import {TOFTInitStruct, TOFTModulesInitStruct} from "contracts/ITOFTv2.sol";
import {Cluster} from "../tapioca-periph/contracts/Cluster/Cluster.sol";
import {SingularityMock} from "./SingularityMock.sol";
import {MagnetarMock} from "./MagnetarMock.sol";
import {TestUtils} from "./TestUtils.t.sol";

contract TOFTTestHelper is TestHelper, TestUtils {
//     function createMagnetar(address cluster, address owner) public returns (MagnetarV2) {
//         MagnetarMarketModule marketModule = new MagnetarMarketModule();
//         return new MagnetarV2(cluster, owner, payable(marketModule));
//     }
    
    function createSingularity(address _yieldBox, uint256 _collateralId, uint256 _assetId, address _collateral, address _asset) public returns (SingularityMock) {
        return new SingularityMock(_yieldBox, _collateralId, _assetId, _collateral, _asset);
    }

    function createYieldBoxEmptyStrategy(address _yieldBox, address _erc20) public returns (ERC20WithoutStrategy) {
        return new ERC20WithoutStrategy(IYieldBox(_yieldBox), IERC20(_erc20));
    }
    function registerYieldBoxAsset(address _yieldBox, address _token, address _strategy) public returns (uint256) {
        return YieldBox(_yieldBox).registerAsset(TokenType.ERC20, _token, IStrategy(_strategy), 0);
    }
    function createMagnetar(address cluster) public returns (MagnetarMock) {
        return new MagnetarMock(cluster);
    }
    
    function createYieldBox() public returns (YieldBox) {
        YieldBoxURIBuilder uriBuilder = new YieldBoxURIBuilder();

        return new YieldBox(IWrappedNative(address(0)), uriBuilder);
    }

    function createCluster(uint32 hostEid, address owner) public returns (Cluster) {
        return new Cluster(hostEid, owner);
    }

    function createInitStruct(string memory name, string memory symbol, address endpoint, address owner, address yieldBox, address cluster, address erc20, uint256 hostEid) public pure returns(TOFTInitStruct memory) {
        return TOFTInitStruct(
            {
                name: name,
                symbol: symbol,
                endpoint: endpoint,
                owner: owner,
                yieldBox: yieldBox,
                cluster: cluster,
                erc20: erc20,
                hostEid: hostEid
            }
        );
    }

    function createModulesInitStruct(address tOFTSenderModule, address tOFTReceiverModule, address marketReceiverModule) public pure returns (TOFTModulesInitStruct memory) {
        return TOFTModulesInitStruct(
            {
                tOFTSenderModule: tOFTSenderModule,
                tOFTReceiverModule: tOFTReceiverModule,
                marketReceiverModule: marketReceiverModule
            }
        );
    }
}
