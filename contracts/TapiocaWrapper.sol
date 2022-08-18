// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
import './TapiocaOFT.sol';

import '@openzeppelin/contracts/utils/Create2.sol';
import '@rari-capital/solmate/src/auth/Owned.sol';

contract TapiocaWrapperError {
    enum ERROR {
        FAILED_DEPLOY,
        MNGMT_FEE_TOO_HIGH
    }
    enum ERROR_MSG {
        TOFT_EXECUTION_FAILED
    }

    /// @notice Failed to deploy the TapiocaWrapper contract.
    error TapiocaWrapper__FailedDeploy();
    /// @notice The management fee is too high. Currently set to a max of 50 BPS or 0.5%.
    error TapiocaWrapper__MngmtFeeTooHigh();
    /// @notice The TapiocaOFT execution failed.
    error TapiocaWrapper__TOFTExecutionFailed(bytes message);

    /// @notice Error management for `TapiocaWrapper`.
    /// @param _statement The statement boolean value.
    /// @param _error The error to throw.
    function __require(bool _statement, ERROR _error) internal pure {
        if (_statement) {
            if (_error == ERROR.FAILED_DEPLOY) {
                revert TapiocaWrapper__FailedDeploy();
            } else if (_error == ERROR.MNGMT_FEE_TOO_HIGH) {
                revert TapiocaWrapper__MngmtFeeTooHigh();
            }
        }
    }

    /// @notice Error management for `TapiocaWrapper`, supports error messages.
    /// @param _statement The statement boolean value.
    /// @param _error The error to throw.
    /// @param _message The error message.
    function __require(
        bool _statement,
        ERROR_MSG _error,
        bytes memory _message
    ) internal pure {
        if (_statement) {
            if (_error == ERROR_MSG.TOFT_EXECUTION_FAILED) {
                revert TapiocaWrapper__TOFTExecutionFailed(_message);
            }
        }
    }
}

contract TapiocaWrapper is Owned, TapiocaWrapperError {
    /// @notice Management fee for a wrap operation. In BPS.
    uint256 public mngmtFee;
    /// @notice Denominator for `mngmtFee`.
    uint256 public constant mngmtFeeFraction = 10000;

    /// @notice Array of deployed TOFT contracts.
    TapiocaOFT[] public tapiocaOFTs;
    /// @notice Map of deployed TOFT contracts by ERC20.
    mapping(address => TapiocaOFT) public tapiocaOFTsByErc20;

    constructor() Owned(msg.sender) {}

    /// @notice Deploy a new TOFT contract. Callable only by the owner.
    /// @param _erc20 The ERC20 to wrap.
    /// @param _bytecode The executable bytecode of the TOFT contract.
    /// @param _salt Create2 salt.
    function createTOFT(
        address _erc20,
        bytes calldata _bytecode,
        bytes32 _salt
    ) external onlyOwner {
        TapiocaOFT toft = TapiocaOFT(
            Create2.deploy(
                0,
                keccak256(
                    abi.encodePacked(
                        keccak256('TapiocaWrapper'),
                        address(this),
                        _erc20,
                        _salt
                    )
                ),
                _bytecode
            )
        );
        __require(address(toft.erc20()) != _erc20, ERROR.FAILED_DEPLOY);

        tapiocaOFTs.push(toft);
        tapiocaOFTsByErc20[_erc20] = toft;
    }

    // ========== TOFT ==========

    /// @notice Execute the `_bytecode` against the `_toft`. Callable only by the owner.
    /// @param _toft The TOFT contract to execute against.
    /// @param _bytecode The executable bytecode of the TOFT contract.
    /// @param _revertOnFailure Whether to revert on failure.
    /// @return success If the execution was successful.
    /// @return result The error message if the execution failed.
    function executeTOFT(
        address _toft,
        bytes calldata _bytecode,
        bool _revertOnFailure
    ) external payable onlyOwner returns (bool success, bytes memory result) {
        (success, result) = payable(_toft).call{value: msg.value}(_bytecode);
        if (_revertOnFailure) {
            __require(!success, ERROR_MSG.TOFT_EXECUTION_FAILED, result);
        }
    }

    /// @notice Return the number of TOFT contracts deployed on the current chain.
    function tapiocaOFTLength() external view returns (uint256) {
        return tapiocaOFTs.length;
    }

    /// @notice Return the latest TOFT contract deployed on the current chain.
    function lastTOFT() external view returns (TapiocaOFT) {
        return tapiocaOFTs[tapiocaOFTs.length - 1];
    }

    // ========== Management ==========
    /// @notice Set the management fee for a wrap operation.
    /// @custom:invariant Forbid a management fee higher than 0.5%.
    /// @param _mngmtFee The new management fee for a wrap operation. In BPS.
    function setMngmtFee(uint256 _mngmtFee) external onlyOwner {
        __require(_mngmtFee > 50, ERROR.MNGMT_FEE_TOO_HIGH);

        mngmtFee = _mngmtFee;
    }
}
