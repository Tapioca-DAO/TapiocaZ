// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Tapioca
import {IYieldBox} from "tapioca-periph/interfaces/yieldbox/IYieldBox.sol";
import {ICommonData} from "tapioca-periph/interfaces/common/ICommonData.sol";
import {IMagnetar} from "tapioca-periph/interfaces/periph/IMagnetar.sol";
import {ICluster} from "tapioca-periph/interfaces/periph/ICluster.sol";
import {IMarket} from "tapioca-periph/interfaces/bar/IMarket.sol";

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

    function depositAddCollateralAndBorrowFromMarket(IMagnetar.DepositAddCollateralAndBorrowFromMarketData memory _data)
        external
        payable
    {
        if (!cluster.isWhitelisted(cluster.lzChainId(), address(_data.market))) revert MagnetarMock_NotAuthorized();

        IYieldBox yieldBox = IYieldBox(IMarket(_data.market).yieldBox());

        uint256 collateralId = IMarket(_data.market).collateralId();
        (, address collateralAddress,,) = yieldBox.assets(collateralId);

        uint256 _share = yieldBox.toShare(collateralId, _data.collateralAmount, false);

        //deposit to YieldBox
        if (_data.deposit) {
            // transfers tokens from sender or from the user to this contract
            _data.collateralAmount = _extractTokens(
                _data.extractFromSender ? msg.sender : _data.user, collateralAddress, _data.collateralAmount
            );
            _share = yieldBox.toShare(collateralId, _data.collateralAmount, false);

            // deposit to YieldBox
            IERC20(collateralAddress).approve(address(yieldBox), 0);
            IERC20(collateralAddress).approve(address(yieldBox), _data.collateralAmount);
            yieldBox.depositAsset(collateralId, address(this), address(this), _data.collateralAmount, 0);
        }

        // performs .addCollateral on market
        if (_data.collateralAmount > 0) {
            yieldBox.setApprovalForAll(address(_data.market), true);
            IMarket(_data.market).addCollateral(
                _data.deposit ? address(this) : _data.user, _data.user, false, _data.collateralAmount, _share
            );
        }

        // performs .borrow on market
        // if `withdraw` it uses `withdrawTo` to withdraw assets on the same chain or to another one
        if (_data.borrowAmount > 0) {
            address borrowReceiver = _data.withdrawParams.withdraw ? address(this) : _data.user;
            IMarket(_data.market).borrow(_data.user, borrowReceiver, _data.borrowAmount);

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

        yieldBox.setApprovalForAll(address(_data.market), false);
    }

    function _extractTokens(address _from, address _token, uint256 _amount) private returns (uint256) {
        uint256 balanceBefore = IERC20(_token).balanceOf(address(this));
        IERC20(_token).safeTransferFrom(_from, address(this), _amount);
        uint256 balanceAfter = IERC20(_token).balanceOf(address(this));
        if (balanceAfter <= balanceBefore) revert MagnetarMock_Failed();
        return balanceAfter - balanceBefore;
    }
}
