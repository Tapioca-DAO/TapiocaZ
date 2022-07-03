// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './OFT20/OFT.sol';

contract TapiocaOFT is OFT {
    ERC20 public immutable erc20; // 0x0 if not on main chain
    uint256 public immutable mainChainID;
    uint8 _decimalCache;

    uint16 constant OPTIMISM_CHAINID = 10;

    // ==========
    // * EVENTS *
    // ==========
    event Wrap(address indexed _from, address indexed _to, uint256 _amount);
    event Unwrap(address indexed _from, address indexed _to, uint256 _amount);

    // ==========
    // * ERRORS *
    // ==========
    error NotMainChain();

    constructor(
        address _lzEndpoint,
        ERC20 _erc20,
        uint8 _mainChainID
    )
        OFT(
            string(abi.encodePacked('TapiocaWrapper-', _erc20.name())),
            string(abi.encodePacked('TW-', _erc20.symbol())),
            _lzEndpoint
        )
    {
        erc20 = _erc20;
        _decimalCache = erc20.decimals();
        mainChainID = _mainChainID;

        // Set trusted remote
        if (getChainId() == _mainChainID) {
            trustedRemoteLookup[OPTIMISM_CHAINID] = abi.encode(address(this));
        } else {
            trustedRemoteLookup[_mainChainID] = abi.encode(address(this));
        }
    }

    modifier onlyMainChain() {
        if (mainChainID != getChainId()) {
            revert NotMainChain();
        }
        _;
    }

    function decimals() public view override returns (uint8) {
        return _decimalCache;
    }

    /// @notice Wrap an ERC20 with a 1:1 ratio
    function wrap(address _toAddress, uint256 _amount) external onlyMainChain {
        erc20.transferFrom(msg.sender, address(this), _amount);
        _mint(_toAddress, _amount);
        emit Wrap(msg.sender, _toAddress, _amount);
    }

    // @notice Unwrap an ERC20 with a 1:1 ratio
    function unwrap(address _toAddress, uint256 _amount)
        external
        onlyMainChain
    {
        _burn(msg.sender, _amount);
        erc20.transfer(_toAddress, _amount);
        emit Unwrap(msg.sender, _toAddress, _amount);
    }

    // Used for mocks
    function getChainId() internal view virtual returns (uint256) {
        return block.chainid;
    }
}
