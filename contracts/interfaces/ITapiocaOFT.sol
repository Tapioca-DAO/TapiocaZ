// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITapiocaOFT {
    function totalFees() external view returns (uint256);

    function erc20() external view returns (IERC20);

    function hostChainID() external view returns (uint256);

    function wrappedAmount(uint256 _amount) external view returns (uint256);

    function wrap(
        address _fromAddress,
        address _toAddress,
        uint256 _amount
    ) external;

    function wrapNative(address _toAddress) external payable;

    function harvestFees() external;

    function unwrap(address _toAddress, uint256 _amount) external;

    function isHostChain() external view returns (bool);

    function balanceOf(address _holder) external view returns (uint256);

    function isNative() external view returns (bool);

    function extractUnderlying(uint256 _amount) external;

    function approve(address _spender, uint256 _amount) external returns (bool);

    function isTrustedRemote(
        uint16 _lzChainId,
        bytes calldata _path
    ) external view returns (bool);
}
