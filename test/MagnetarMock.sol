// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External 
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";


// Tapioca
import {IYieldBoxBase} from "../tapioca-periph/contracts/interfaces/IYieldBoxBase.sol";
import {ICommonData} from "../tapioca-periph/contracts/interfaces/ICommonData.sol";
import {ICluster} from "../tapioca-periph/contracts/interfaces/ICluster.sol";
import {IMarket} from "../tapioca-periph/contracts/interfaces/IMarket.sol";

import "forge-std/console.sol";

/*
* @dev need this because of via-ir: true error on original Magnetar
**/
contract MagnetarMock {
    using SafeERC20 for IERC20;

    error MagnetarMock_NotAuthorized();
    error MagnetarMock_Failed();

    ICluster public cluster;

    constructor(address _cluster) {
        cluster = ICluster(_cluster);
    }

    function depositAddCollateralAndBorrowFromMarket(
        IMarket market,
        address user,
        uint256 collateralAmount,
        uint256 borrowAmount,
        bool extractFromSender,
        bool deposit,
        ICommonData.IWithdrawParams calldata withdrawParams
    ) external payable {
        if (!cluster.isWhitelisted(cluster.lzChainId(), address(market))) revert MagnetarMock_NotAuthorized(); 

         IYieldBoxBase yieldBox = IYieldBoxBase(market.yieldBox());

    
        uint256 collateralId = market.collateralId();
        (, address collateralAddress, , ) = yieldBox.assets(collateralId);

        uint256 _share = yieldBox.toShare(
            collateralId,
            collateralAmount,
            false
        );

        //deposit to YieldBox
        if (deposit) {
            // transfers tokens from sender or from the user to this contract
            collateralAmount = _extractTokens(
                extractFromSender ? msg.sender : user,
                collateralAddress,
                collateralAmount
            );
            _share = yieldBox.toShare(collateralId, collateralAmount, false);

            // deposit to YieldBox
            IERC20(collateralAddress).approve(address(yieldBox), 0);
            IERC20(collateralAddress).approve(
                address(yieldBox),
                collateralAmount
            );
            yieldBox.depositAsset(
                collateralId,
                address(this),
                address(this),
                collateralAmount,
                0
            );
        }

        // performs .addCollateral on market
        if (collateralAmount > 0) {
            yieldBox.setApprovalForAll(address(market), true);
            market.addCollateral(
                deposit ? address(this) : user,
                user,
                false,
                collateralAmount,
                _share
            );
        }

        // performs .borrow on market
        // if `withdraw` it uses `withdrawTo` to withdraw assets on the same chain or to another one
        if (borrowAmount > 0) {
            address borrowReceiver = withdrawParams.withdraw
                ? address(this)
                : user;
            market.borrow(user, borrowReceiver, borrowAmount);

            // if (withdrawParams.withdraw) {
                // bytes memory withdrawAssetBytes = abi.encode(
                //     withdrawParams.withdrawOnOtherChain,
                //     withdrawParams.withdrawLzChainId,
                //     LzLib.addressToBytes32(user),
                //     withdrawParams.withdrawAdapterParams
                // );
                // _withdraw(
                //     borrowReceiver,
                //     withdrawAssetBytes,
                //     market,
                //     yieldBox,
                //     borrowAmount,
                //     false,
                //     valueAmount,
                //     false,
                //     withdrawParams.refundAddress,
                //     withdrawParams.zroPaymentAddress
                // );
            // }
        }

        yieldBox.setApprovalForAll(address(market), false);
    }

    function _extractTokens(
        address _from,
        address _token,
        uint256 _amount
    ) private returns (uint256) {
        uint256 balanceBefore = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransferFrom(_from, address(this), _amount);
        uint256 balanceAfter = IERC20(_token).balanceOf(address(this));
        if (balanceAfter <= balanceBefore) revert MagnetarMock_Failed();
        return balanceAfter - balanceBefore;
    }
}