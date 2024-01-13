// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {ExecutorOptions} from "@layerzerolabs/lz-evm-protocol-v2/contracts/messagelib/libs/ExecutorOptions.sol";
import {IOAppMsgInspector} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppMsgInspector.sol";
import {SendParam, MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";

// External
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BytesLib} from "@layerzerolabs/solidity-bytes-utils/contracts/BytesLib.sol";

// Tapioca
import {TOFTInitStruct} from "./ITOFTv2.sol";
import {IYieldBoxBase} from "tapioca-periph/contracts/interfaces/IYieldBoxBase.sol";
import {ICluster} from "tapioca-periph/contracts/interfaces/ICluster.sol";

/*
__/\\\\\\\\\\\\\\\_____/\\\\\\\\\_____/\\\\\\\\\\\\\____/\\\\\\\\\\\_______/\\\\\_____________/\\\\\\\\\_____/\\\\\\\\\____        
 _\///////\\\/////____/\\\\\\\\\\\\\__\/\\\/////////\\\_\/////\\\///______/\\\///\\\________/\\\////////____/\\\\\\\\\\\\\__       
  _______\/\\\________/\\\/////////\\\_\/\\\_______\/\\\_____\/\\\_______/\\\/__\///\\\____/\\\/____________/\\\/////////\\\_      
   _______\/\\\_______\/\\\_______\/\\\_\/\\\\\\\\\\\\\/______\/\\\______/\\\______\//\\\__/\\\_____________\/\\\_______\/\\\_     
    _______\/\\\_______\/\\\\\\\\\\\\\\\_\/\\\/////////________\/\\\_____\/\\\_______\/\\\_\/\\\_____________\/\\\\\\\\\\\\\\\_    
     _______\/\\\_______\/\\\/////////\\\_\/\\\_________________\/\\\_____\//\\\______/\\\__\//\\\____________\/\\\/////////\\\_   
      _______\/\\\_______\/\\\_______\/\\\_\/\\\_________________\/\\\______\///\\\__/\\\_____\///\\\__________\/\\\_______\/\\\_  
       _______\/\\\_______\/\\\_______\/\\\_\/\\\______________/\\\\\\\\\\\____\///\\\\\/________\////\\\\\\\\\_\/\\\_______\/\\\_ 
        _______\///________\///________\///__\///______________\///////////_______\/////_____________\/////////__\///________\///__

*/

contract BaseTOFTv2 is OFT {
    using BytesLib for bytes;
    using SafeERC20 for IERC20;
    using OFTMsgCodec for bytes;
    using OFTMsgCodec for bytes32;

    // LZ packets
    uint16 internal constant PT_YB_SEND_STRAT = 770;
    uint16 internal constant PT_YB_RETRIEVE_STRAT = 771;
    uint16 internal constant PT_MARKET_REMOVE_COLLATERAL = 772;
    uint16 internal constant PT_YB_SEND_SGL_BORROW = 775;
    uint16 internal constant PT_LEVERAGE_MARKET_DOWN = 776;
    uint16 internal constant PT_TAP_EXERCISE = 777;
    uint16 internal constant PT_TRIGGER_SEND_FROM = 778;
    uint16 internal constant PT_APPROVE = 779;
    uint16 internal constant PT_SEND_FROM_PARAMS = 780;

    // VARS

    IYieldBoxBase public immutable yieldBox;
    ICluster public cluster;
    address public erc20;
    uint256 public hostEid;

    uint256 internal constant SLIPPAGE_PRECISION = 1e4;

    // ERRORS
    error NotValid();

    constructor(
        TOFTInitStruct memory data
    ) OFT(data.name, data.symbol, data.endpoint, data.owner) {
        yieldBox = IYieldBoxBase(data.yieldBox);
        cluster = ICluster(data.cluster);
        erc20 = data.erc20;
        hostEid = data.hostEid;
    }
}
