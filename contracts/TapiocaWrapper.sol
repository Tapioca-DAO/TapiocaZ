// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;
import './TapiocaOFT.sol';

import '@openzeppelin/contracts/utils/Create2.sol';
import '@rari-capital/solmate/src/auth/Owned.sol';

contract TapiocaWrapper is Owned {
    /// @notice Management fee for a wrap operation. In BPS.
    uint256 public mngmtFee;
    /// @notice Denominator for `mngmtFee`.
    uint256 public constant mngmtFeeFraction = 10000;

    /// @notice Array of deployed TOFT contracts.
    TapiocaOFT[] public tapiocaOFTs;
    /// @notice Map of deployed TOFT contracts by ERC20.
    mapping(address => TapiocaOFT) public tapiocaOFTsByErc20;

    /// =========
    /// * ERRORS *
    /// =========
    error TapiocaWrapper__MngmtFeeTooHigh();

    /// @notice Forbid a management fee higher than 0.5%
    function _require__MngmtFeeTooHigh(uint256 _mngmtFee) internal pure {
        if (_mngmtFee > 50) {
            revert TapiocaWrapper__MngmtFeeTooHigh();
        }
    }

    constructor() Owned(msg.sender) {}

    /// @notice Deploy a new TOFT contract. Callable only by the owner.
    /// @param _erc20 The ERC20 to wrap.
    /// @param _bytecode The executable bytecode of the TOFT contract.
    function createTOFT(address _erc20, bytes calldata _bytecode)
        external
        onlyOwner
    {
        TapiocaOFT toft = TapiocaOFT(
            Create2.deploy(
                0,
                keccak256(
                    abi.encodePacked(keccak256('TapiocaWrapper'), _erc20)
                ),
                _bytecode
            )
        );
        tapiocaOFTs.push(toft);
        tapiocaOFTsByErc20[_erc20] = toft;

        require(address(toft.erc20()) == _erc20, 'ERC20 address mismatch');
    }

    // ========== TOFT ==========

    /// @notice Execute the `_bytecode` against the `_toft`. Callable only by the owner.
    /// @param _toft The TOFT contract to execute against.
    /// @param _bytecode The executable bytecode of the TOFT contract.
    function executeTOFT(address _toft, bytes calldata _bytecode)
        external
        payable
        onlyOwner
        returns (bool success)
    {
        (success, ) = payable(_toft).call{value: msg.value}(_bytecode);
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
    /// @param _mngmtFee The new management fee for a wrap operation. In BPS.
    function setMngmtFee(uint256 _mngmtFee) external onlyOwner {
        _require__MngmtFeeTooHigh(_mngmtFee);

        mngmtFee = _mngmtFee;
    }
}
