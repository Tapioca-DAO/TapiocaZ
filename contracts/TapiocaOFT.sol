// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "./BaseTOFT.sol";


contract TapiocaOFT is BaseTOFT {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    /// @notice creates a new TapiocaOFT
    /// @param _lzEndpoint LayerZero endpoint address
    /// @param _erc20 true the underlying ERC20 address
    /// @param _yieldBox the YieldBox address
    /// @param _name the TOFT name
    /// @param _symbol the TOFT symbol
    /// @param _decimal the TOFT decimal
    /// @param _hostChainID the TOFT host chain LayerZero id
    constructor(
        address _lzEndpoint,
        address _erc20,
        IYieldBoxBase _yieldBox,
        string memory _name,
        string memory _symbol,
        uint8 _decimal,
        uint256 _hostChainID
    )
        BaseTOFT(
            _lzEndpoint,
            _erc20,
            _yieldBox,
            _name,
            _symbol,
            _decimal,
            _hostChainID
        )
    {}

    // ************************ //
    // *** PUBLIC FUNCTIONS *** //
    // ************************ //
    /// @notice Wrap an ERC20 with a 1:1 ratio with a fee if existing.
    /// @dev Since it can be executed only on the main chain, if an address exists on the OP chain it will not allowed to wrap.
    /// @param _fromAddress The address to wrap from.
    /// @param _toAddress The address to wrap the ERC20 to.
    /// @param _amount The amount of ERC20 to wrap.
    function wrap(
        address _fromAddress,
        address _toAddress,
        uint256 _amount
    ) external payable onlyHostChain {
        if (_isNative()) {
            _wrapNative(_toAddress);
        } else {
            _wrap(_fromAddress, _toAddress, _amount);
        }
    }

    /// @notice Unwrap an ERC20/Native with a 1:1 ratio. Called only on host chain.
    /// @param _toAddress The address to unwrap the tokens to.
    /// @param _amount The amount of tokens to unwrap.

    function unwrap(
        address _toAddress,
        uint256 _amount
    ) external onlyHostChain {
        _unwrap(_toAddress, _amount);
    }
}
