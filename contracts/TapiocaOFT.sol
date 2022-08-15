// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './OFT20/OFT.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import './OFT20/interfaces/ILayerZeroEndpoint.sol';
import './TapiocaWrapper.sol';

contract TapiocaOFT is OFT {
    using SafeERC20 for IERC20;

    TapiocaWrapper public tapiocaWrapper;
    uint256 public totalFees;

    IERC20 public immutable erc20;
    uint256 public immutable mainChainID;
    uint8 _decimalCache;

    uint16 constant OPTIMISM_CHAINID = 10;

    // ==========
    // * EVENTS *
    // ==========
    event Wrap(address indexed _from, address indexed _to, uint256 _amount);
    event Unwrap(address indexed _from, address indexed _to, uint256 _amount);
    event Harvest(address indexed _caller, uint256 _amount);

    // ==========
    // * ERRORS *
    // ==========

    // @notice Code executed not on main chain (optimism/chainID mismatch)
    error TOFT__NotMainChain();

    constructor(
        address _lzEndpoint,
        IERC20 _erc20,
        string memory _name,
        string memory _symbol,
        uint8 _decimal,
        uint16 _mainChainID
    )
        OFT(
            string(abi.encodePacked('TapiocaWrapper-', _name)),
            string(abi.encodePacked('TW-', _symbol)),
            _lzEndpoint
        )
    {
        erc20 = _erc20;
        _decimalCache = _decimal;
        mainChainID = _mainChainID;

        // Set trusted remote
        if (getChainId() == _mainChainID) {
            trustedRemoteLookup[OPTIMISM_CHAINID] = abi.encode(address(this));
        } else {
            trustedRemoteLookup[_mainChainID] = abi.encode(address(this));
        }

        tapiocaWrapper = TapiocaWrapper(msg.sender);
    }

    modifier onlyMainChain() {
        if (getChainId() != mainChainID) {
            revert TOFT__NotMainChain();
        }
        _;
    }

    function decimals() public view override returns (uint8) {
        return _decimalCache;
    }

    /// @notice Wrap an ERC20 with a 1:1 ratio
    function wrap(address _toAddress, uint256 _amount) external onlyMainChain {
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

    // @notice Harvest the fees collected by the contract
    function harvestFees() external onlyMainChain {
        erc20.safeTransfer(address(tapiocaWrapper), totalFees);
        emit Harvest(msg.sender, totalFees);
        totalFees = 0;
    }

    // @notice Unwrap an ERC20 with a 1:1 ratio
    function unwrap(address _toAddress, uint256 _amount)
        external
        onlyMainChain
    {
        _burn(msg.sender, _amount);
        erc20.safeTransfer(_toAddress, _amount);
        emit Unwrap(msg.sender, _toAddress, _amount);
    }

    // @notice Estimate the fees for a wrap operation
    function estimateFees(
        uint256 _feeBps,
        uint256 _feeFraction,
        uint256 _amount
    ) public pure returns (uint256) {
        return (_amount * _feeBps) / _feeFraction;
    }

    function isMainChain() external view returns (bool) {
        return getChainId() == mainChainID;
    }

    // Used for mocks
    function getChainId() internal view virtual returns (uint256) {
        return ILayerZeroEndpoint(lzEndpoint).getChainId();
    }
}
