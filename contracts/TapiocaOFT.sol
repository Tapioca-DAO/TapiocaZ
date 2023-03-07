// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './BaseTOFT.sol';
import "./TapiocaWrapper.sol";

//
//                 .(%%%%%%%%%%%%*       *
//             #%%%%%%%%%%%%%%%%%%%%*  ####*
//          #%%%%%%%%%%%%%%%%%%%%%#  /####
//       ,%%%%%%%%%%%%%%%%%%%%%%%   ####.  %
//                                #####
//                              #####
//   #####%#####              *####*  ####%#####*
//  (#########(              #####     ##########.
//  ##########             #####.      .##########
//                       ,####/
//                      #####
//  %%%%%%%%%%        (####.           *%%%%%%%%%#
//  .%%%%%%%%%%     *####(            .%%%%%%%%%%
//   *%%%%%%%%%%   #####             #%%%%%%%%%%
//               (####.
//      ,((((  ,####(          /(((((((((((((
//        *,  #####  ,(((((((((((((((((((((
//          (####   ((((((((((((((((((((/
//         ####*  (((((((((((((((((((
//                     ,**//*,.

contract TapiocaOFT is BaseTOFT {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    /// @notice The TapiocaWrapper contract, owner of this contract.
    TapiocaWrapper public tapiocaWrapper;

    constructor(
        address _lzEndpoint,
        bool _isNative,
        IERC20 _erc20,
        IYieldBox _yieldBox,
        string memory _name,
        string memory _symbol,
        uint8 _decimal,
        uint256 _hostChainID
    ) BaseTOFT(_lzEndpoint, _isNative, _erc20, _yieldBox, _name, _symbol, _decimal, _hostChainID, ITapiocaWrapper(msg.sender)) {
        tapiocaWrapper = TapiocaWrapper(msg.sender);
    }

    // ********************** //
    // *** VIEW FUNCTIONS *** //
    // ********************** //
    /// @notice Return the output amount of an ERC20 token wrap operation.
    function wrappedAmount(uint256 _amount) public view returns (uint256) {
        return _amount - estimateFees(tapiocaWrapper.mngmtFee(), tapiocaWrapper.mngmtFeeFraction(), _amount);
    }

    // ************************ //
    // *** PUBLIC FUNCTIONS *** //
    // ************************ //
    /// @notice Wrap an ERC20 with a 1:1 ratio with a fee if existing.
    /// @dev Since it can be executed only on the main chain, if an address exists on the OP chain it will not allowed to wrap.
    /// @param _toAddress The address to wrap the ERC20 to.
    /// @param _amount The amount of ERC20 to wrap.
    function wrap(address _toAddress, uint256 _amount) external onlyHostChain {
        _wrap(_toAddress, _amount, tapiocaWrapper.mngmtFee(), tapiocaWrapper.mngmtFeeFraction());
    }

    /// @notice Wrap a native token with a 1:1 ratio with a fee if existing.
    /// @dev Since it can be executed only on the host chain, if an address exists on the linked chain it will not allowed to wrap.
    /// @param _toAddress The address to wrap the tokens to.
    function wrapNative(address _toAddress) external payable onlyHostChain {
        _wrapNative(_toAddress, tapiocaWrapper.mngmtFee(), tapiocaWrapper.mngmtFeeFraction());
    }

    /// @notice Harvest the fees collected by the contract. Called only on host chain.
    function harvestFees() external onlyHostChain {
        _harvestFees(address(tapiocaWrapper.owner()));
    }

    /// @notice Unwrap an ERC20/Native with a 1:1 ratio. Called only on host chain.
    /// @param _toAddress The address to unwrap the tokens to.
    /// @param _amount The amount of tokens to unwrap.
    function unwrap(address _toAddress, uint256 _amount) external onlyHostChain {
        _unwrap(_toAddress, _amount);
    }
}
