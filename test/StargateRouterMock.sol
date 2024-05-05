// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IStargateRouterMock {
    struct lzTxObj {
        uint256 dstGasForCall;
        uint256 dstNativeAmount;
        bytes dstNativeAddr;
    }

    function swap(
        uint16 _dstChainId,
        uint256 _srcPoolId,
        uint256 _dstPoolId,
        address payable _refundAddress,
        uint256 _amountLD,
        uint256 _minAmountLD,
        lzTxObj memory _lzTxParams,
        bytes calldata _to,
        bytes calldata _payload
    ) external payable;
}

interface IToftMock {
    function sgReceive(uint16, bytes memory, uint256, address, uint256 amountLD, bytes memory) external;
}

contract StargateFactoryMock {
    address public pool;

    constructor() {
        pool = address(new StargatePoolMock());
    }

    function getPool(uint256) external view returns (address) {
        return pool;
    }
}

contract StargatePoolMock {
    function localDecimals() external pure returns (uint256) {
        return 18;
    }

    function sharedDecimals() external pure returns (uint256) {
        return 18;
    }

    function convertRate() external pure returns (uint256) {
        return 1;
    }
}

contract StargateRouterMock is IStargateRouterMock {
    IERC20 public token;

    constructor(IERC20 _token) {
        token = _token;
    }

    function swap(
        uint16,
        uint256,
        uint256,
        address payable _refundAddress,
        uint256 _amountLD,
        uint256,
        IStargateRouterMock.lzTxObj memory,
        bytes memory _to,
        bytes calldata
    ) external payable override {
        require(_amountLD > 0, "Stargate: cannot swap 0");
        require(_refundAddress != address(0x0), "Stargate: _refundAddress cannot be 0x0");

        address tempAddress;
        assembly {
            let offset := add(_to, 20)
            tempAddress := mload(offset)
        }

        token.transferFrom(msg.sender, address(this), _amountLD);
        token.transfer(tempAddress, _amountLD);

        IToftMock(tempAddress).sgReceive(0, "0x", 0, address(0), _amountLD, "0x");
    }
}
