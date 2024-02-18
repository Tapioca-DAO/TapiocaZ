// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

/**
 * @title TOFTVault
 * @author TapiocaDAO
 * @notice Holds TOFT funds
 */
contract TOFTVault is Ownable {
    using SafeERC20 for IERC20;

    address public _token;
    bool private _isNative;
    uint256 private _fees;

    error NotValid();
    error ZeroAmount();
    error Failed();
    error FeesAmountNotRight();
    error AmountNotRight();
    error OwnerSet();

    constructor(address token_) {
        _token = token_;
        _isNative = token_ == address(0);

        _transferOwnership(address(0));
    }

    /// =====================
    /// View
    /// =====================
    /// @notice returns total active supply including fees
    function viewTotalSupply() external view returns (uint256) {
        return viewSupply() + viewFees();
    }

    /// @notice returns total active supply
    /// @dev fees are not taken into account
    function viewSupply() public view returns (uint256) {
        if (_isNative) {
            return address(this).balance - _fees;
        }
        return IERC20(_token).balanceOf(address(this)) - _fees;
    }

    /// @notice returns fees amount
    function viewFees() public view returns (uint256) {
        return _fees;
    }

    /// =====================
    /// Owner
    /// =====================

    /// @dev Intended to be called once by the TOFT contract
    function claimOwnership() external {
        if (owner() != address(0)) revert OwnerSet();
        _transferOwnership(msg.sender);
    }

    /// @notice register fees for mTOFT
    function registerFees(uint256 amount) external payable onlyOwner {
        if (msg.value > 0 && msg.value != amount) revert FeesAmountNotRight();
        _fees += amount;
    }

    /// @notice transfers fees out of the vault
    /// @dev the receiver is usually the Balancer.sol contract
    /// @param to receiver
    /// @param amount the extracted amount
    function transferFees(address to, uint256 amount) external onlyOwner {
        if (amount > _fees) revert FeesAmountNotRight();
        _fees -= amount;
        _withdraw(to, amount);
    }

    /// @notice deposit native gas to vault
    function depositNative() external payable onlyOwner {
        if (!_isNative) revert NotValid();
        if (msg.value == 0) revert ZeroAmount();
    }

    /// @notice extracts from vault
    /// @param to receiver
    /// @param amount the extracted amount
    function withdraw(address to, uint256 amount) external onlyOwner {
        _withdraw(to, amount);
    }

    /// =====================
    /// Private
    /// =====================
    function _withdraw(address to, uint256 amount) private {
        if (amount > viewSupply()) revert AmountNotRight();
        if (_isNative) {
            (bool success,) = to.call{value: amount}("");
            if (!success) revert Failed();
        } else {
            IERC20(_token).safeTransfer(to, amount);
        }
    }
}
