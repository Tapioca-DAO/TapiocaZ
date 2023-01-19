// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './TapiocaWrapper.sol';
import './BaseTOFT.sol';

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
    /// @notice A zero amount was found
    error TOFT_ZeroAmount();

    /// ==========================
    /// ========== Events ========
    /// ==========================
    event Wrap(address indexed _from, address indexed _to, uint256 _amount);
    event Unwrap(address indexed _from, address indexed _to, uint256 _amount);
    event HarvestFees(uint256 _amount);

    constructor(
        address _lzEndpoint,
        bool _isNative,
        IERC20 _erc20,
        IYieldBox _yieldBox,
        string memory _name,
        string memory _symbol,
        uint8 _decimal,
        uint256 _hostChainID
    )
        OFT(
            string(abi.encodePacked('TapiocaOFT-', _name)),
            string(abi.encodePacked('TOFT-', _symbol)),
            _lzEndpoint
        )
        BaseTOFT(_isNative, _yieldBox)
    {
        if (isNative) {
            require(address(_erc20) == address(0), 'TOFT__NotNative');
        }

        erc20 = _erc20;
        _decimalCache = _decimal;
        hostChainID = _hostChainID;

        tapiocaWrapper = TapiocaWrapper(msg.sender);
    }

    /// @notice Require that the caller is on the host chain of the ERC20.
    modifier onlyHostChain() {
        if (block.chainid != hostChainID) {
            revert TOFT__NotHostChain();
        }
        _;
    }

    /// @notice Decimal number of the ERC20
    function decimals() public view override returns (uint8) {
        return _decimalCache;
    }

    /// @notice Return the output amount of an ERC20 token wrap operation.
    function wrappedAmount(uint256 _amount) public view returns (uint256) {
        return
            _amount -
            estimateFees(
                tapiocaWrapper.mngmtFee(),
                tapiocaWrapper.mngmtFeeFraction(),
                _amount
            );
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

    /// @notice Wrap a native token with a 1:1 ratio with a fee if existing.
    /// @dev Since it can be executed only on the host chain, if an address exists on the linked chain it will not allowed to wrap.
    /// @param _toAddress The address to wrap the tokens to.
    function wrapNative(address _toAddress) external payable onlyHostChain {
        if (msg.value == 0) {
            revert TOFT_ZeroAmount();
        }

        uint256 toMint;
        uint256 mngmtFee = tapiocaWrapper.mngmtFee();

        if (mngmtFee > 0) {
            uint256 feeAmount = estimateFees(
                mngmtFee,
                tapiocaWrapper.mngmtFeeFraction(),
                msg.value
            );

            totalFees += feeAmount;
            toMint = msg.value - feeAmount;
        }

        _mint(_toAddress, toMint);
        emit Wrap(msg.sender, _toAddress, toMint);
    }

    /// @notice Harvest the fees collected by the contract. Called only on host chain.
    function harvestFees() external onlyHostChain {
        erc20.safeTransfer(address(tapiocaWrapper.owner()), totalFees);
        totalFees = 0;
        emit HarvestFees(totalFees);
    }

    /// @notice Unwrap an ERC20/Native with a 1:1 ratio. Called only on host chain.
    /// @param _toAddress The address to unwrap the tokens to.
    /// @param _amount The amount of tokens to unwrap.
    function unwrap(address _toAddress, uint256 _amount)
        external
        onlyHostChain
    {
        _burn(msg.sender, _amount);

        if (isNative) {
            safeTransferETH(_toAddress, _amount);
        } else {
            erc20.safeTransfer(_toAddress, _amount);
        }

        emit Unwrap(msg.sender, _toAddress, _amount);
    }

    // ================================
    // ========== INTERNAL ============
    // ================================

    /// @notice Estimate the management fees for a wrap operation.
    function estimateFees(
        uint256 _feeBps,
        uint256 _feeFraction,
        uint256 _amount
    ) public pure returns (uint256) {
        return (_amount * _feeBps) / _feeFraction;
    }

    /// @notice Author: Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/SafeTransferLib.sol)
    function safeTransferETH(address to, uint256 amount) internal {
        bool success;

        assembly {
            // Transfer the ETH and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(success, 'ETH_TRANSFER_FAILED');
    }

    // ==========================
    // ========== LZ ============
    // ==========================

    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) internal virtual override {
        uint16 packetType;
        assembly {
            packetType := mload(add(_payload, 32))
        }

        if (packetType == PT_SEND) {
            _sendAck(_srcChainId, _srcAddress, _nonce, _payload);
        } else if (packetType == PT_YB_SEND_STRAT) {
            _ybDeposit(_srcChainId, _payload, IERC20(address(this)), true);
        } else if (packetType == PT_YB_RETRIEVE_STRAT) {
            _ybWithdraw(_srcChainId, _payload, true);
        } else if (packetType == PT_YB_DEPOSIT) {
            _ybDeposit(_srcChainId, _payload, IERC20(address(this)), false);
        } else if (packetType == PT_YB_WITHDRAW) {
            _ybWithdraw(_srcChainId, _payload, false);
        } else {
            revert('OFTCore: unknown packet type');
        }
    }

    /// @notice Check if the current chain is the host chain of the ERC20.
    function isHostChain() external view returns (bool) {
        return block.chainid == hostChainID;
    }

    function getLzChainId() external view returns (uint16) {
        return lzEndpoint.getChainId();
    }
}
