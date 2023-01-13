// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import 'tapioca-sdk/dist/contracts/libraries/LzLib.sol';
import 'tapioca-sdk/dist/contracts/token/oft/OFT.sol';
import './interfaces/IYieldBox.sol';

import 'hardhat/console.sol';

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

abstract contract BaseTOFT is OFT {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    /// @notice The YieldBox address.
    IYieldBox public immutable yieldBox;
    /// @notice If this wrapper is for an ERC20 or a native token.
    bool isNative;

    uint16 public constant PT_YB_SEND_STRAT = 770;
    uint16 public constant PT_YB_RETRIEVE_STRAT = 771;
    uint16 public constant PT_YB_DEPOSIT = 772;
    uint16 public constant PT_YB_WITHDRAW = 773;

    /// ==========================
    /// ========== Errors ========
    /// ==========================
    /// @notice Error while depositing ETH assets to YieldBox.
    error TOFT_YB_ETHDeposit();

    /// ==========================
    /// ========== Events ========
    /// ==========================
    event YieldBoxDeposit(uint256 _amount);
    event YieldBoxRetrieval(uint256 _amount);

    constructor(bool _isNative, IYieldBox _yieldBox) {
        yieldBox = _yieldBox;
        isNative = _isNative;
    }

    receive() external payable {}

    // ==========================
    // ========== LZ ============
    // ==========================
    function sendToYB(
        uint256 amount,
        uint256 assetId,
        uint256 minShareOut,
        uint16 lzDstChainId,
        uint256 extraGasLimit,
        address zroPaymentAddress,
        bool strategyDeposit
    ) external payable {
        bytes memory toAddress = abi.encodePacked(msg.sender);
        _debitFrom(msg.sender, lzEndpoint.getChainId(), toAddress, amount);
        bytes memory lzPayload = abi.encode(
            strategyDeposit ? PT_YB_SEND_STRAT : PT_YB_DEPOSIT,
            abi.encodePacked(msg.sender),
            toAddress,
            amount,
            assetId,
            minShareOut
        );
        bytes memory adapterParam = LzLib.buildDefaultAdapterParams(
            extraGasLimit
        );
        _lzSend(
            lzDstChainId,
            lzPayload,
            payable(msg.sender),
            zroPaymentAddress,
            adapterParam,
            msg.value
        );
        emit SendToChain(lzDstChainId, msg.sender, toAddress, amount);
    }

    function retrieveFromYB(
        uint256 amount,
        uint256 assetId,
        uint16 lzDstChainId,
        uint256 extraGasLimit,
        address zroPaymentAddress,
        address airdropAddress,
        uint256 airdropAmount,
        bool strategyWithdrawal
    ) external payable {
        bytes memory toAddress = abi.encodePacked(msg.sender);

        bytes memory airdropAdapterParam = LzLib.buildAirdropAdapterParams(
            extraGasLimit,
            LzLib.AirdropParams({
                airdropAmount: airdropAmount,
                airdropAddress: bytes32(uint256(uint160(airdropAddress)) << 96) //LzLib has an issue converting address to bytes32
            })
        );
        bytes memory lzPayload = abi.encode(
            strategyWithdrawal ? PT_YB_RETRIEVE_STRAT : PT_YB_WITHDRAW,
            abi.encodePacked(msg.sender),
            toAddress,
            amount,
            0,
            assetId,
            zroPaymentAddress
        );
        _lzSend(
            lzDstChainId,
            lzPayload,
            payable(msg.sender),
            zroPaymentAddress,
            airdropAdapterParam,
            msg.value
        );
        emit SendToChain(lzDstChainId, msg.sender, toAddress, amount);
    }

    // ================================
    // ========== YieldBox ============
    // ================================

    function _ybDeposit(
        uint16 _srcChainId,
        bytes memory _payload,
        IERC20 _erc20,
        bool _strategyDeposit
    ) internal virtual {
        (
            ,
            //package
            bytes memory fromAddressBytes, //from
            ,
            uint256 amount,
            uint256 assetId,
            uint256 minShareOut
        ) = abi.decode(
                _payload,
                (uint16, bytes, bytes, uint256, uint256, uint256)
            );

        address onBehalfOf = _strategyDeposit
            ? address(this)
            : fromAddressBytes.toAddress(0);
        _creditTo(_srcChainId, address(this), amount);
        _depositToYieldbox(
            assetId,
            amount,
            minShareOut,
            _erc20,
            address(this),
            onBehalfOf
        );

        emit ReceiveFromChain(_srcChainId, onBehalfOf, amount);
    }

    function _ybWithdraw(
        uint16 _srcChainId,
        bytes memory _payload,
        bool _strategyWithdrawal
    ) internal virtual {
        (
            ,
            bytes memory from,
            ,
            uint256 _amount,
            uint256 _share,
            uint256 _assetId,
            address _zroPaymentAddress
        ) = abi.decode(
                _payload,
                (uint16, bytes, bytes, uint256, uint256, uint256, address)
            );

        address _from = from.toAddress(0);
        _retrieveFromYieldBox(
            _assetId,
            _amount,
            _share,
            _strategyWithdrawal ? address(this) : _from,
            address(this)
        );

        _debitFrom(
            address(this),
            lzEndpoint.getChainId(),
            abi.encodePacked(address(this)),
            _amount
        );
        bytes memory lzSendBackPayload = abi.encode(PT_SEND, from, _amount);
        _lzSend(
            _srcChainId,
            lzSendBackPayload,
            payable(this),
            _zroPaymentAddress,
            '',
            address(this).balance
        );
        emit SendToChain(
            _srcChainId,
            _from,
            abi.encodePacked(address(this)),
            _amount
        );

        emit ReceiveFromChain(_srcChainId, _from, _amount);
    }

    /// @notice Receive an inter-chain transaction to execute a deposit inside YieldBox.
    function _depositToYieldbox(
        uint256 _assetId,
        uint256 _amount,
        uint256 _minShareOut,
        IERC20 _erc20,
        address _from,
        address _to
    ) private {
        if (isNative) {
            bytes memory depositETHAssetData = abi.encodeWithSelector(
                yieldBox.depositETHAsset.selector,
                _assetId,
                address(this),
                _minShareOut
            );
            (bool success, ) = address(yieldBox).call{value: _amount}(
                depositETHAssetData
            );
            if (!success) {
                revert TOFT_YB_ETHDeposit();
            }
        } else {
            _erc20.approve(address(yieldBox), _amount);
            yieldBox.depositAsset(
                _assetId,
                _from,
                _to,
                _amount,
                0,
                _minShareOut
            );
        }

        emit YieldBoxDeposit(_amount);
    }

    /// @notice Receive an inter-chain transaction to execute a deposit inside YieldBox.
    function _retrieveFromYieldBox(
        uint256 _assetId,
        uint256 _amount,
        uint256 _share,
        address _from,
        address _to
    ) private {
        yieldBox.withdraw(_assetId, _from, _to, _amount, _share);

        emit YieldBoxRetrieval(_amount);
    }
}
