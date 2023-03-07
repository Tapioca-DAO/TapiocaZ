// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

/// @notice common operations
library TransferLib {
    /// @notice Author: Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SafeTransferLib.sol)
    function safeTransferETH(address to, uint256 amount) internal {
        bool success;

        assembly {
            // Transfer the ETH and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(success, "ETH_TRANSFER_FAILED");
    }
}
