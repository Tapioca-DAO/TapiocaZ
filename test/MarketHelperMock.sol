// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {Rebase} from "@boringcrypto/boring-solidity/contracts/libraries/BoringRebase.sol";

import {IMarketLiquidatorReceiver} from "tapioca-periph/interfaces/bar/IMarketLiquidatorReceiver.sol";
import {ITapiocaOracle} from "tapioca-periph/interfaces/periph/ITapiocaOracle.sol";
import {ISingularity} from "tapioca-periph/interfaces/bar/ISingularity.sol";
import {IYieldBox} from "tapioca-periph/interfaces/yieldbox/IYieldBox.sol";
import {IMarket, Module} from "tapioca-periph/interfaces/bar/IMarket.sol";
import {SingularityMock} from "./SingularityMock.sol";

contract MarketHelperMock {
    error ExchangeRateNotValid();

    /// @notice Adds `collateral` from msg.sender to the account `to`.
    /// @param from Account to transfer shares from.
    /// @param to The receiver of the tokens.
    /// @param skim True if the amount should be skimmed from the deposit balance of msg.sender.
    /// False if tokens from msg.sender in `yieldBox` should be transferred.
    /// @param share The amount of shares to add for `to`.
    function addCollateral(address from, address to, bool skim, uint256 amount, uint256 share)
        external
        pure
        returns (Module[] memory modules, bytes[] memory calls)
    {
        modules = new Module[](1);
        calls = new bytes[](1);
        modules[0] = Module.Collateral;
        calls[0] = abi.encodeWithSelector(SingularityMock.addCollateral.selector, from, to, skim, amount, share);
    }

    /// @notice Removes `share` amount of collateral and transfers it to `to`.
    /// @param from Account to debit collateral from.
    /// @param to The receiver of the shares.
    /// @param share Amount of shares to remove.
    function removeCollateral(address from, address to, uint256 share)
        external
        pure
        returns (Module[] memory modules, bytes[] memory calls)
    {
        modules = new Module[](1);
        calls = new bytes[](1);
        modules[0] = Module.Collateral;
        calls[0] = abi.encodeWithSelector(SingularityMock.removeCollateral.selector, from, to, share);
    }

    /// @notice Sender borrows `amount` and transfers it to `to`.
    /// @param from Account to borrow for.
    /// @param to The receiver of borrowed tokens.
    /// @param amount Amount to borrow.
    function borrow(address from, address to, uint256 amount)
        external
        pure
        returns (Module[] memory modules, bytes[] memory calls)
    {
        modules = new Module[](1);
        calls = new bytes[](1);
        modules[0] = Module.Borrow;
        calls[0] = abi.encodeWithSelector(SingularityMock.borrow.selector, from, to, amount);
    }

    /// @notice View the result of a borrow operation.
    function borrowView(bytes calldata result) external pure returns (uint256 part, uint256 share) {
        (part, share) = abi.decode(result, (uint256, uint256));
    }

    /// @notice Lever up: Borrow more and buy collateral with it.
    /// @param from The user who buys
    /// @param borrowAmount Amount of extra asset borrowed
    /// @param supplyAmount Amount of asset supplied (down payment)
    /// @param data LeverageExecutor data
    function buyCollateral(address from, uint256 borrowAmount, uint256 supplyAmount, bytes calldata data)
        external
        pure
        returns (Module[] memory modules, bytes[] memory calls)
    {
        modules = new Module[](1);
        calls = new bytes[](1);
        modules[0] = Module.Leverage;
        calls[0] =
            abi.encodeWithSelector(SingularityMock.buyCollateral.selector, from, borrowAmount, supplyAmount, data);
    }

    /// @notice view the result of a buyCollateral operation.
    function buyCollateralView(bytes calldata result) external pure returns (uint256 amountOut) {
        amountOut = abi.decode(result, (uint256));
    }

    function _getRevertMsg(bytes memory _returnData) internal pure returns (string memory) {
        if (_returnData.length > 1000) return "Market: reason too long";
        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "Market: no return data";
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }
}
