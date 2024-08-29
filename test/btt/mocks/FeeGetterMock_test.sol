// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

contract FeeGetterMock_test {
    uint256 _percentage = 1e4;
    uint256 constant PERCENTAGE_PRECISION = 1e5;

    function setPercentage(uint256 _perc) external {
        require(_perc < PERCENTAGE_PRECISION, "not valid");
        _percentage = _perc;
    }

    function getWrapFee(uint256) external pure returns (uint256) {
        return 0;
    }
    function getUnwrapFee(uint256 _amount) external view returns (uint256) {
        if (_percentage == 0) return _amount;
        return _amount * _percentage / PERCENTAGE_PRECISION;
    }
}