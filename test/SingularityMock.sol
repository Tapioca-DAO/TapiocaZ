// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External 
import {IYieldBoxBase} from "../tapioca-periph/contracts/interfaces/IYieldBoxBase.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SingularityMock {
    IYieldBoxBase public yieldBox;
    uint256 collateralId;
    uint256 assetId;
    IERC20 collateral;
    IERC20 asset;

       /// @notice total collateral supplied
    uint256 public totalCollateralShare;
    /// @notice borrow amount per user
    mapping(address => uint256) public userBorrowPart;
    /// @notice collateral share per user
    mapping(address => uint256) public userCollateralShare;

    error SingularityMock_TooMuch();

    constructor(address _yieldBox, uint256 _collateralId, uint256 _assetId, address _collateral, address _asset) {
        yieldBox = IYieldBoxBase(_yieldBox);
        collateralId = _collateralId;
        assetId = _assetId;
        collateral = IERC20(_collateral);
        asset = IERC20(_asset);
    }

     function borrow(
        address from,
        address to,
        uint256 amount
    )
        external
        returns (uint256 part, uint256 share)
    {
        if (amount == 0) return (0, 0);

        userBorrowPart[from] += amount;

        share = yieldBox.toShare(assetId, amount, true);
        yieldBox.transfer(address(this), to, assetId, share);

    }

    function addCollateral(
        address from,
        address to,
        bool skim,
        uint256 amount,
        uint256 share
    ) external {
        if (share == 0) {
            share = yieldBox.toShare(collateralId, amount, false);
        }

        uint256 oldTotalCollateralShare = totalCollateralShare;
        userCollateralShare[to] += share;
        totalCollateralShare = oldTotalCollateralShare + share;

        _addTokens(
            from,
            to,
            collateralId,
            share,
            oldTotalCollateralShare,
            skim
        );
    }


     function _addTokens(
        address from,
        address,
        uint256 _assetId,
        uint256 share,
        uint256 total,
        bool skim
    ) internal {
        if (skim) {
            if (share > yieldBox.balanceOf(address(this), _assetId) - total)
                revert SingularityMock_TooMuch();
        } else {
            yieldBox.transfer(from, address(this), _assetId, share);
        }
    }
}