// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.22;

// External
import {IERC20} from "@boringcrypto/boring-solidity/contracts/interfaces/IERC20.sol";

// Lz
import {TestHelper} from "./LZSetup/TestHelper.sol";

// Tapioca
import {TOFTInitStruct, TOFTModulesInitStruct} from "tapioca-periph/interfaces/oft/ITOFT.sol";
import {ERC20WithoutStrategy} from "yieldbox/strategies/ERC20WithoutStrategy.sol";
import {IPearlmit} from "tapioca-periph/interfaces/periph/IPearlmit.sol";
import {IWrappedNative} from "yieldbox/interfaces/IWrappedNative.sol";
import {YieldBoxURIBuilder} from "yieldbox/YieldBoxURIBuilder.sol";
import {TokenType} from "yieldbox/enums/YieldBoxTokenType.sol";
import {IYieldBox} from "yieldbox/interfaces/IYieldBox.sol";
import {IStrategy} from "yieldbox/interfaces/IStrategy.sol";
import {Cluster} from "tapioca-periph/Cluster/Cluster.sol";
import {SingularityMock} from "./SingularityMock.sol";
import {MagnetarMock} from "./MagnetarMock.sol";
import {YieldBox} from "yieldbox/YieldBox.sol";
import {TestUtils} from "./TestUtils.t.sol";

contract TOFTTestHelper is TestHelper, TestUtils {
    //     function createMagnetar(address cluster, address owner) public returns (MagnetarV2) {
    //         MagnetarMarketModule marketModule = new MagnetarMarketModule();
    //         return new MagnetarV2(cluster, owner, payable(marketModule));
    //     }

    function createSingularity(
        address _yieldBox,
        uint256 _collateralId,
        uint256 _assetId,
        address _collateral,
        address _asset
    ) public returns (SingularityMock) {
        return new SingularityMock(_yieldBox, _collateralId, _assetId, _collateral, _asset);
    }

    function createYieldBoxEmptyStrategy(address _yieldBox, address _erc20) public returns (ERC20WithoutStrategy) {
        return new ERC20WithoutStrategy(IYieldBox(_yieldBox), IERC20(_erc20));
    }

    function registerYieldBoxAsset(address _yieldBox, address _token, address _strategy) public returns (uint256) {
        return YieldBox(_yieldBox).registerAsset(TokenType.ERC20, _token, IStrategy(_strategy), 0);
    }

    function createMagnetar(address cluster, IPearlmit pearlmit) public returns (MagnetarMock) {
        return new MagnetarMock(cluster, pearlmit);
    }

    function createYieldBox() public returns (YieldBox) {
        YieldBoxURIBuilder uriBuilder = new YieldBoxURIBuilder();

        return new YieldBox(IWrappedNative(address(0)), uriBuilder);
    }

    function createCluster(uint32 hostEid, address owner) public returns (Cluster) {
        return new Cluster(hostEid, owner);
    }
}
