// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

interface IMarketHelper {
    /// @notice deposits collateral to YieldBox, adds collateral to Singularity, borrows and can withdraw to personal address
    /// @param market the Singularity or BigBang address
    /// @param _user the address to deposit from and withdraw to
    /// @param _collateralAmount the collateral amount to add
    /// @param _borrowAmount the amount to borrow
    /// @param deposit_ if true, deposits to YieldBox from `msg.sender`
    /// @param withdraw_ if true, withdraws from YieldBox to `msg.sender`
    /// @param _withdrawData custom withdraw data; ignore if you need to withdraw on the same chain
    function depositAddCollateralAndBorrow(
        address market,
        address _user,
        uint256 _collateralAmount,
        uint256 _borrowAmount,
        bool deposit_,
        bool withdraw_,
        bytes calldata _withdrawData
    ) external payable;

    /// @notice deposits asset to YieldBox and lends it to Singularity
    /// @param singularity the singularity address
    /// @param _user the address to deposit from and lend to
    /// @param _amount the amount to lend
    function depositAndAddAsset(
        address singularity,
        address _user,
        uint256 _amount,
        bool deposit_
    ) external;
}
