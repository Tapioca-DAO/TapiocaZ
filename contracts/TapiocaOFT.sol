// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './OFT20/OFT.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './OFT20/interfaces/ILayerZeroEndpoint.sol';
import './TapiocaWrapper.sol';

contract TapiocaOFT is OFT {
    using SafeERC20 for IERC20;

    /// @notice The TapiocaWrapper contract, owner of this contract.
    TapiocaWrapper public tapiocaWrapper;
    /// @notice Total fees amassed by this contract, in `erc20`.
    uint256 public totalFees;
    /// @notice The ERC20 to wrap.
    IERC20 public immutable erc20;
    /// @notice The host chain ID of the ERC20, will be used only on OP chain.
    uint256 public immutable hostChainID;
    /// @notice Decimal cache number of the ERC20.
    uint8 _decimalCache;

    /// ==========================
    /// ========== Errors ========
    /// ==========================

    /// @notice Code executed not on main chain (optimism/chainID mismatch).
    error TOFT__NotHostChain();

    /// ==========================
    /// ========== Events ========
    /// ==========================
    event Wrap(address indexed _from, address indexed _to, uint256 _amount);
    event Unwrap(address indexed _from, address indexed _to, uint256 _amount);
    event Harvest(uint256 _amount);

    constructor(
        address _lzEndpoint,
        IERC20 _erc20,
        string memory _name,
        string memory _symbol,
        uint8 _decimal,
        uint16 _hostChainID
    )
        OFT(
            string(abi.encodePacked('TapiocaOFT-', _name)),
            string(abi.encodePacked('TOFT-', _symbol)),
            _lzEndpoint
        )
    {
        erc20 = _erc20;
        _decimalCache = _decimal;
        hostChainID = _hostChainID;

        tapiocaWrapper = TapiocaWrapper(msg.sender);
    }

    /// @notice Require that the caller is on the host chain of the ERC20.
    modifier onlyHostChain() {
        if (getChainId() != hostChainID) {
            revert TOFT__NotHostChain();
        }
        _;
    }

    /// @notice Decimal number of the ERC20
    function decimals() public view override returns (uint8) {
        return _decimalCache;
    }

    /// @notice Wrap an ERC20 with a 1:1 ratio with a fee if existing.
    /// @dev Since it can be executed only on the main chain, if an address exists on the OP chain it will not allowed to wrap.
    /// @param _toAddress The address to wrap the ERC20 to.
    /// @param _amount The amount of ERC20 to wrap.
    function wrap(address _toAddress, uint256 _amount) external onlyHostChain {
        uint256 mngmtFee = tapiocaWrapper.mngmtFee();

        if (mngmtFee > 0) {
            uint256 feeAmount = estimateFees(
                mngmtFee,
                tapiocaWrapper.mngmtFeeFraction(),
                _amount
            );

            totalFees += feeAmount;
            erc20.safeTransferFrom(
                msg.sender,
                address(this),
                _amount + feeAmount
            );
        } else {
            erc20.safeTransferFrom(msg.sender, address(this), _amount);
        }

        _mint(_toAddress, _amount);
        emit Wrap(msg.sender, _toAddress, _amount);
    }

    /// @notice Harvest the fees collected by the contract. Called only on main chain.
    function harvestFees() external onlyHostChain {
        erc20.safeTransfer(address(tapiocaWrapper.owner()), totalFees);
        totalFees = 0;
        emit Harvest(totalFees);
    }

    /// @notice Unwrap an ERC20 with a 1:1 ratio. Called only on main chain.
    /// @param _toAddress The address to unwrap the ERC20 to.
    /// @param _amount The amount of ERC20 to unwrap.
    function unwrap(address _toAddress, uint256 _amount)
        external
        onlyHostChain
    {
        _burn(msg.sender, _amount);
        erc20.safeTransfer(_toAddress, _amount);
        emit Unwrap(msg.sender, _toAddress, _amount);
    }

    /// @notice Estimate the management fees for a wrap operation.
    function estimateFees(
        uint256 _feeBps,
        uint256 _feeFraction,
        uint256 _amount
    ) public pure returns (uint256) {
        return (_amount * _feeBps) / _feeFraction;
    }

    /// @notice Check if the current chain is the main chain of the ERC20.
    function isHostChain() external view returns (bool) {
        return getChainId() == hostChainID;
    }

    /// @notice Return the current Layer-Zero "chain ID", not the actual `chainId` OPCODE output.
    /// @dev Useful for testing.
    function getChainId() internal view virtual returns (uint256) {
        return ILayerZeroEndpoint(lzEndpoint).getChainId();
    }
}
