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
    /// @notice Array of harvestable TOFT fees.
    TapiocaOFT[] private harvestableTapiocaOFTs;
    /// @notice Map of deployed TOFT contracts by ERC20.
    mapping(address => TapiocaOFT) public tapiocaOFTsByErc20;

    /// ==========================
    /// ========== Events ========
    /// ==========================

    /// @notice Called when a new OFT is deployed.
    event CreateOFT(TapiocaOFT indexed _tapiocaOFT, address indexed _erc20);
    /// @notice Called when fees are harvested.
    event HarvestFees(address indexed _caller);
    /// @notice Called when fees are changed.
    event SetFees(uint256 _newFee);

    /// ==========================
    /// ========== Errors ========
    /// ==========================

    /// @notice Failed to deploy the TapiocaWrapper contract.
    error TapiocaWrapper__FailedDeploy();
    /// @notice The management fee is too high. Currently set to a max of 50 BPS or 0.5%.
    error TapiocaWrapper__MngmtFeeTooHigh();
    /// @notice The TapiocaOFT execution failed.
    error TapiocaWrapper__TOFTExecutionFailed(bytes message);
    /// @notice No TOFT has been deployed yet.
    error TapiocaWrapper__NoTOFTDeployed();

    constructor() Owned(msg.sender) {}

    /// ==========================
    /// ========== TOFT ==========
    /// ==========================

    /// @notice Return the number of TOFT contracts deployed on the current chain.
    function tapiocaOFTLength() external view returns (uint256) {
        return tapiocaOFTs.length;
    }

    /// @notice Return the number of harvestable TOFT contracts deployed on the current chain.
    function harvestableTapiocaOFTsLength() external view returns (uint256) {
        return harvestableTapiocaOFTs.length;
    }

    /// @notice Return the latest TOFT contract deployed on the current chain.
    function lastTOFT() external view returns (TapiocaOFT) {
        if (tapiocaOFTs.length == 0) {
            revert TapiocaWrapper__NoTOFTDeployed();
        }
        return tapiocaOFTs[tapiocaOFTs.length - 1];
    }

    /// ================================
    /// ========== Management ==========
    /// ================================

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
        if (address(toft.erc20()) != _erc20) {
            revert TapiocaWrapper__FailedDeploy();
        }

        tapiocaOFTs.push(toft);
        tapiocaOFTsByErc20[_erc20] = toft;

        if (toft.isMainChain()) {
            harvestableTapiocaOFTs.push(toft);
        }
        emit CreateOFT(toft, _erc20);
    }

    /// @notice Harvest fees from all the deployed TOFT contracts. Fees are transferred to the owner.
    function harvestFees() external {
        for (uint256 i = 0; i < harvestableTapiocaOFTs.length; i++) {
            harvestableTapiocaOFTs[i].harvestFees();
        }
        emit HarvestFees(msg.sender);
    }

    /// @notice Set the management fee for a wrap operation.
    /// @custom:invariant Forbid a management fee higher than 0.5%.
    /// @param _mngmtFee The new management fee for a wrap operation. In BPS.
    function setMngmtFee(uint256 _mngmtFee) external onlyOwner {
        if (_mngmtFee > 50) {
            revert TapiocaWrapper__MngmtFeeTooHigh();
        }

        mngmtFee = _mngmtFee;
        emit SetFees(mngmtFee);
    }

    /// @notice Execute the `_bytecode` against the `_toft`. Callable only by the owner.
    /// @dev Used to call derived OFT functions to a TOFT contract.
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
        if (_revertOnFailure && !success) {
            revert TapiocaWrapper__TOFTExecutionFailed(result);
        }
    }
}
