// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

//LZ
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol";

//TAPIOCA
import {IUSDOBase} from "tapioca-periph/contracts/interfaces/IUSDO.sol";
import "tapioca-periph/contracts/interfaces/ITapiocaOFT.sol";
import "tapioca-periph/contracts/interfaces/IMagnetar.sol";
import "tapioca-periph/contracts/interfaces/IMarket.sol";

import "./TOFTCommon.sol";

contract BaseTOFTMarketDestinationModule is TOFTCommon {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    // ************** //
    // *** ERRORS *** //
    // ************** //
    error GasNotValid();

    constructor(
        address _lzEndpoint,
        address _erc20,
        IYieldBoxBase _yieldBox,
        ICluster _cluster,
        string memory _name,
        string memory _symbol,
        uint8 _decimal,
        uint256 _hostChainID
    )
        BaseTOFTStorage(
            _lzEndpoint,
            _erc20,
            _yieldBox,
            _cluster,
            _name,
            _symbol,
            _decimal,
            _hostChainID
        )
    {}

    function borrow(
        address module,
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) public payable {
        if (
            msg.sender != address(this) ||
            _moduleAddresses[Module.MarketDestination] != module
        ) revert NotAuthorized();
        (
            ,
            address _from, //from
            bytes32 _to,
            uint64 amountSD,
            ITapiocaOFT.IBorrowParams memory borrowParams,
            ICommonData.IWithdrawParams memory withdrawParams,
            ICommonData.IApproval[] memory approvals,
            ICommonData.IApproval[] memory revokes,
            uint256 airdropAmount
        ) = abi.decode(
                _payload,
                (
                    uint16,
                    address,
                    bytes32,
                    uint64,
                    ITapiocaOFT.IBorrowParams,
                    ICommonData.IWithdrawParams,
                    ICommonData.IApproval[],
                    ICommonData.IApproval[],
                    uint256
                )
            );

        borrowParams.amount = _sd2ld(amountSD);

        uint256 balanceBefore = balanceOf(address(this));
        _checkCredited(borrowParams.amount, _srcChainId, _srcAddress, _nonce);

        if (approvals.length > 0) {
            _callApproval(approvals, PT_YB_SEND_SGL_BORROW);
        }
        (bool success, bytes memory reason) = module.delegatecall(
            abi.encodeWithSelector(
                this.borrowInternal.selector,
                module,
                _to,
                borrowParams,
                withdrawParams,
                airdropAmount
            )
        );
        if (revokes.length > 0) {
            _callApproval(revokes, PT_YB_SEND_SGL_BORROW);
        }

        if (!success) {
            _storeAndSend(
                balanceOf(address(this)) - balanceBefore >= borrowParams.amount,
                borrowParams.amount,
                _from,
                reason,
                _srcChainId,
                _srcAddress,
                _nonce,
                _payload
            );
        }

        emit ReceiveFromChain(_srcChainId, _from, borrowParams.amount);
    }

    function _checkCredited(
        uint256 amount,
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce
    ) private {
        bool credited = creditedPackets[_srcChainId][_srcAddress][_nonce];
        if (!credited) {
            _creditTo(_srcChainId, address(this), amount);
            creditedPackets[_srcChainId][_srcAddress][_nonce] = true;
        }
    }

    function _storeAndSend(
        bool refund,
        uint256 amount,
        address leverageFor,
        bytes memory reason,
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) private {
        if (refund) {
            IERC20(address(this)).safeTransfer(leverageFor, amount);
        }
        _storeFailedMessage(_srcChainId, _srcAddress, _nonce, _payload, reason);
    }

    function borrowInternal(
        address module,
        bytes32 _to,
        ITapiocaOFT.IBorrowParams memory borrowParams,
        ICommonData.IWithdrawParams memory withdrawParams,
        uint256 airdropAmount
    ) public payable {
        if (
            msg.sender != address(this) ||
            _moduleAddresses[Module.MarketDestination] != module
        ) revert NotAuthorized();

        // Use market helper to deposit, add collateral to market and withdrawTo
        approve(address(borrowParams.marketHelper), borrowParams.amount);

        IMagnetar(borrowParams.marketHelper)
            .depositAddCollateralAndBorrowFromMarket{value: airdropAmount}(
            borrowParams.market,
            LzLib.bytes32ToAddress(_to),
            borrowParams.amount,
            borrowParams.borrowAmount,
            true,
            true,
            withdrawParams
        );
    }

    function remove(
        address,
        uint16,
        bytes memory,
        uint64,
        bytes memory _payload
    ) public {
        if (msg.sender != address(this)) revert NotAuthorized();
        (
            ,
            address from,
            bytes32 toBytes,
            uint64 removeCollateralAmount,
            ITapiocaOFT.IRemoveParams memory removeParams,
            ICommonData.IWithdrawParams memory withdrawParams,
            ICommonData.IApproval[] memory approvals,
            ICommonData.IApproval[] memory revokes,
            uint256 airdropAmount
        ) = abi.decode(
                _payload,
                (
                    uint16,
                    address,
                    bytes32,
                    uint64,
                    ITapiocaOFT.IRemoveParams,
                    ICommonData.IWithdrawParams,
                    ICommonData.IApproval[],
                    ICommonData.IApproval[],
                    uint256
                )
            );

        address to = LzLib.bytes32ToAddress(toBytes);
        if (approvals.length > 0) {
            _callApproval(approvals, PT_MARKET_REMOVE_COLLATERAL);
        }

        removeParams.amount = _sd2ld(removeCollateralAmount);

        address ybAddress = IMarket(removeParams.market).yieldBox();
        uint256 assetId = IMarket(removeParams.market).collateralId();

        uint256 share = IYieldBoxBase(ybAddress).toShare(
            assetId,
            removeParams.amount,
            false
        );

        //market whitelist status
        if (removeParams.market != address(0)) {
            if (!cluster.isWhitelisted(0, removeParams.market))
                revert NotAuthorized();
        }
        approve(removeParams.market, share);
        IMarket(removeParams.market).removeCollateral(from, to, share);
        if (withdrawParams.withdraw) {
            if (airdropAmount < withdrawParams.withdrawLzFeeAmount)
                revert GasNotValid();
            if (!cluster.isWhitelisted(0, removeParams.marketHelper))
                revert NotAuthorized();
            IMagnetar(removeParams.marketHelper).withdrawToChain{
                value: withdrawParams.withdrawLzFeeAmount
            }(
                ybAddress,
                to,
                assetId,
                withdrawParams.withdrawLzChainId,
                LzLib.addressToBytes32(to),
                removeParams.amount,
                withdrawParams.withdrawAdapterParams,
                payable(to),
                withdrawParams.withdrawLzFeeAmount,
                withdrawParams.unwrap
            );
        }

        if (revokes.length > 0) {
            _callApproval(revokes, PT_MARKET_REMOVE_COLLATERAL);
        }
    }
}
