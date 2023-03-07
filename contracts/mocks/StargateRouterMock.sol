// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IStargateRouter.sol";

contract StargateRouterMock is IStargateRouterBase {
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
        IStargateRouter.lzTxObj memory,
        bytes calldata _to,
        bytes calldata
    ) external payable override {
        require(_amountLD > 0, "Stargate: cannot swap 0");
        require(
            _refundAddress != address(0x0),
            "Stargate: _refundAddress cannot be 0x0"
        );
        bytes32 converted = bytes32(_to[:32]);
        address tempAddress = address(uint160(uint256(converted)));

        token.transferFrom(msg.sender, address(this), _amountLD);
        token.transfer(tempAddress, _amountLD);
    }
}
