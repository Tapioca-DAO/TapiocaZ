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
