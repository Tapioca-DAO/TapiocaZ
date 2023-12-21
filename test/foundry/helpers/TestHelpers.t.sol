// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../../../contracts/tOFT/TapiocaOFT.sol";
import "../../../contracts/tOFT/modules/BaseTOFTGenericModule.sol";
import "../../../contracts/tOFT/modules/BaseTOFTLeverageDestinationModule.sol";
import "../../../contracts/tOFT/modules/BaseTOFTLeverageModule.sol";
import "../../../contracts/tOFT/modules/BaseTOFTMarketDestinationModule.sol";
import "../../../contracts/tOFT/modules/BaseTOFTMarketModule.sol";
import "../../../contracts/tOFT/modules/BaseTOFTOptionsDestinationModule.sol";
import "../../../contracts/tOFT/modules/BaseTOFTOptionsModule.sol";
import "../../../contracts/tOFT/modules/BaseTOFTStrategyDestinationModule.sol";
import "../../../contracts/tOFT/modules/BaseTOFTStrategyModule.sol";

import "../../../gitsub_tapioca-sdk/src/contracts/mocks/LZEndpointMock.sol";
import "../../../gitsub_tapioca-sdk/src/contracts/mocks/ERC20Mock.sol";
import "../../../gitsub_tapioca-sdk/src/contracts/YieldBox/contracts/YieldBox.sol";
import "../../../gitsub_tapioca-sdk/src/contracts/YieldBox/contracts/YieldBoxURIBuilder.sol";
import "../../../gitsub_tapioca-sdk/src/contracts/YieldBox/contracts/interfaces/IWrappedNative.sol";

abstract contract TestHelper {

    function createYieldBox() public returns (YieldBox) {
        YieldBoxURIBuilder uriBuilder = new YieldBoxURIBuilder();

        return new YieldBox(IWrappedNative(address(0)), uriBuilder);
    }

    function createErc20Mock(string calldata name, string calldata symbol) public returns (ERC20Mock) {
        return ERC20Mock(name, symbol);
    }

    function createLzEndpointMock() public returns (LZEndpointMock) {
        return new LZEndpointMock(1);
    }

    function createOft() public {
        return new TapiocaOFT(createLzEndpointMock())
    }
}