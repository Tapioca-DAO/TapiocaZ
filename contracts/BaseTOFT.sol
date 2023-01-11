// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import 'tapioca-sdk/dist/contracts/token/oft/OFT.sol';
import './interfaces/IYieldBox.sol';

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
    uint16 public constant PT_YB_WITHDRAW = 772;

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

    // ================================
    // ========== YieldBox ============
    // ================================
    /// @notice Should be called by the strategy on the linked chain.
    function _ybSendStrat(
        uint16 _srcChainId,
        bytes memory,
        uint64,
        bytes memory _payload,
        IERC20 _erc20
    ) internal virtual {
        (, , , uint256 amount, uint256 assetId, uint256 minShareOut) = abi
            .decode(
                _payload,
                (uint16, bytes, bytes, uint256, uint256, uint256)
            );

        _creditTo(_srcChainId, address(this), amount);
        _depositToYieldbox(
            assetId,
            amount,
            minShareOut,
            _erc20,
            address(this),
            address(this)
        );

        emit ReceiveFromChain(_srcChainId, address(this), amount);
    }

    /// @notice Should be called by the strategy on the linked chain.
    function _ybRetrieveStrat(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64,
        bytes memory _payload
    ) internal virtual {
        (
            ,
            ,
            ,
            uint256 amount,
            uint256 share,
            uint256 assetId,
            bytes memory _adapterParams
        ) = abi.decode(
                _payload,
                (uint16, bytes, bytes, uint256, uint256, uint256, bytes)
            );

        _retrieveFromYieldBox(
            assetId,
            amount,
            share,
            address(this),
            address(this)
        );

        _send(
            address(this),
            _srcChainId,
            _srcAddress,
            amount,
            payable(_srcAddress.toAddress(0)),
            address(0),
            _adapterParams
        );

        emit ReceiveFromChain(_srcChainId, address(this), amount);
    }

    function _ybDeposit(
        uint16 _srcChainId,
        bytes memory _payload,
        IERC20 _erc20
    ) internal virtual {
        (
            ,
            bytes memory from,
            ,
            uint256 amount,
            uint256 assetId,
            uint256 minShareOut
        ) = abi.decode(
                _payload,
                (uint16, bytes, bytes, uint256, uint256, uint256)
            );

        address _from = from.toAddress(0);
        _creditTo(_srcChainId, address(this), amount);
        _depositToYieldbox(
            assetId,
            amount,
            minShareOut,
            _erc20,
            address(this),
            _from //deposit on behalf of the user
        );

        emit ReceiveFromChain(_srcChainId, _from, amount);
    }

    function _ybWithdraw(uint16 _srcChainId, bytes memory _payload)
        internal
        virtual
    {
        (
            ,
            bytes memory from,
            ,
            uint256 amount,
            uint256 share,
            uint256 assetId,
            bytes memory _adapterParams
        ) = abi.decode(
                _payload,
                (uint16, bytes, bytes, uint256, uint256, uint256, bytes)
            );

        address _from = from.toAddress(0);
        _retrieveFromYieldBox(assetId, amount, share, _from, address(this));

        _send(
            address(this),
            _srcChainId,
            from,
            amount,
            payable(_from),
            address(0),
            _adapterParams
        );

        emit ReceiveFromChain(_srcChainId, _from, amount);
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
