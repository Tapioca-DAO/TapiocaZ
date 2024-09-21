// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {IMtoftFeeGetter} from "../../../gitmodule/tapioca-periph/contracts/interfaces/oft/IMToftFeeGetter.sol";

contract MockMtoftFeeGetter is IMtoftFeeGetter {
    uint256 public constant FEE = 1e18;

    function getWrapFee(uint256 _amount) external pure override returns (uint256) {
        return FEE;
    }

    function getUnwrapFee(uint256 _amount) external pure override returns (uint256) {
        return FEE;
    }
}
