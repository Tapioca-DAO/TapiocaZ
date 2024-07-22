// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PearlmitHandler, IPearlmit} from "tap-utils/pearlmit/PearlmitHandler.sol";

contract OTapMock {
    address public owner;

    // IERC721(oTap).isApprovedForAll(oTapOwner,_options.from)
    function ownerOf(uint256) external view returns (address) {
        return owner != address(0) ? owner : msg.sender;
    }

    function setOwner(address _owner) external {
        owner = _owner;
    }

    function isApprovedForAll(address, address) external pure returns (bool) {
        return true;
    }
}

contract TapiocaOptionsBrokerMock is PearlmitHandler {
    using SafeERC20 for IERC20;

    address public tapOFT;
    uint256 public paymentTokenAmount;
    address public oTapMock;

    error TapiocaOptionsBrokerMock_NotValid();

    constructor(address _tap, IPearlmit _pearlmit) PearlmitHandler(_pearlmit) {
        tapOFT = _tap;
        oTapMock = address(new OTapMock());
    }

    function setPaymentTokenAmount(uint256 _am) external {
        paymentTokenAmount = _am;
    }

    // @dev make sure to set `paymentTokenAmount` before call
    // @dev contract needs enough `tapOFT` for this to be executed successfully
    function exerciseOption(uint256, IERC20 _paymentToken, uint256 _tapAmount) external {
        // @dev 10% is subtracted to test out payment token refund
        uint256 actualPaymentTokenAmount = paymentTokenAmount - paymentTokenAmount * 1e4 / 1e5;

        // IERC20(address(_paymentToken)).safeTransferFrom(msg.sender, address(this), actualPaymentTokenAmount);
        bool isErr =
            pearlmit.transferFromERC20(msg.sender, address(this), address(_paymentToken), actualPaymentTokenAmount);
        if (isErr) revert TapiocaOptionsBrokerMock_NotValid();
        IERC20(tapOFT).safeTransfer(msg.sender, _tapAmount);
    }

    function oTAP() external view returns (address) {
        return address(oTapMock);
    }
}
