// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {IMtoftFeeGetter} from "tap-utils/interfaces/oft/IMToftFeeGetter.sol";

abstract contract Types {
    struct SetOwnerStateData {
        address stargateRouter;
        IMtoftFeeGetter feeGetter;
        uint256 mintCap;
        // connected chains
        uint256 connectedChain;
        bool connectedChainState;
        // balancer
        address balancerStateAddress;
        bool balancerState;
    }
}