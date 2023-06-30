// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

//LZ
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol";

//TAPIOCA
import {IUSDOBase} from "tapioca-periph/contracts/interfaces/IUSDO.sol";
import "tapioca-periph/contracts/interfaces/ISwapper.sol";
import "tapioca-periph/contracts/interfaces/ITapiocaOFT.sol";
import "tapioca-periph/contracts/interfaces/IMagnetar.sol";
import "tapioca-periph/contracts/interfaces/IMarket.sol";
import "tapioca-periph/contracts/interfaces/IPermitBorrow.sol";
import "tapioca-periph/contracts/interfaces/IPermitAll.sol";

import "../BaseTOFTStorage.sol";

contract BaseTOFTMarketModule is BaseTOFTStorage {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    constructor(
        address _lzEndpoint,
        address _erc20,
        IYieldBoxBase _yieldBox,
        string memory _name,
        string memory _symbol,
        uint8 _decimal,
        uint256 _hostChainID
    )
        BaseTOFTStorage(
            _lzEndpoint,
            _erc20,
            _yieldBox,
            _name,
            _symbol,
            _decimal,
            _hostChainID
        )
    {}

    function removeCollateral(
        address from,
        address to,
        uint16 lzDstChainId,
        address zroPaymentAddress,
        ICommonData.IWithdrawParams calldata withdrawParams,
        ITapiocaOFT.IRemoveParams calldata removeParams,
        ICommonData.IApproval[] calldata approvals,
        bytes calldata adapterParams
    ) external payable {
        bytes32 toAddress = LzLib.addressToBytes32(to);

        bytes memory lzPayload = abi.encode(
            PT_MARKET_REMOVE_COLLATERAL,
            from,
            to,
            toAddress,
            removeParams,
            withdrawParams,
            approvals
        );

        _lzSend(
            lzDstChainId,
            lzPayload,
            payable(from),
            zroPaymentAddress,
            adapterParams,
            msg.value
        );

        emit SendToChain(lzDstChainId, from, toAddress, 0);
    }

    /// @notice sends TOFT to a specific chain and performs a borrow operation
    /// @param _from the sender address
    /// @param _to the receiver address
    /// @param lzDstChainId the destination LayerZero id
    /// @param airdropAdapterParams the LayerZero aidrop adapter params
    /// @param borrowParams the borrow operation data
    /// @param withdrawParams the withdraw operation data
    /// @param options the cross chain send operation data
    /// @param approvals the cross chain approval operation data
    function sendToYBAndBorrow(
        address _from,
        address _to,
        uint16 lzDstChainId,
        bytes calldata airdropAdapterParams,
        ITapiocaOFT.IBorrowParams calldata borrowParams,
        ICommonData.IWithdrawParams calldata withdrawParams,
        ICommonData.ISendOptions calldata options,
        ICommonData.IApproval[] calldata approvals
    ) external payable {
        bytes32 toAddress = LzLib.addressToBytes32(_to);
        _debitFrom(
            _from,
            lzEndpoint.getChainId(),
            toAddress,
            borrowParams.amount
        );

        bytes memory lzPayload = abi.encode(
            PT_YB_SEND_SGL_BORROW,
            _from,
            toAddress,
            borrowParams,
            withdrawParams,
            approvals
        );

        _lzSend(
            lzDstChainId,
            lzPayload,
            payable(_from),
            options.zroPaymentAddress,
            airdropAdapterParams,
            msg.value
        );

        emit SendToChain(lzDstChainId, _from, toAddress, borrowParams.amount);
    }

    function borrow(
        address module,
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) public payable {
        (
            ,
            address _from, //from
            bytes32 _to,
            ITapiocaOFT.IBorrowParams memory borrowParams,
            ICommonData.IWithdrawParams memory withdrawParams,
            ICommonData.IApproval[] memory approvals
        ) = abi.decode(
                _payload,
                (
                    uint16,
                    address,
                    bytes32,
                    ITapiocaOFT.IBorrowParams,
                    ICommonData.IWithdrawParams,
                    ICommonData.IApproval[]
                )
            );

        uint256 balanceBefore = balanceOf(address(this));
        bool credited = creditedPackets[_srcChainId][_srcAddress][_nonce];
        if (!credited) {
            _creditTo(_srcChainId, address(this), borrowParams.amount);
            creditedPackets[_srcChainId][_srcAddress][_nonce] = true;
        }
        uint256 balanceAfter = balanceOf(address(this));

        (bool success, bytes memory reason) = module.delegatecall(
            abi.encodeWithSelector(
                this.borrowInternal.selector,
                _from,
                _to,
                borrowParams,
                withdrawParams,
                approvals
            )
        );

        if (!success) {
            if (balanceAfter - balanceBefore >= borrowParams.amount) {
                IERC20(address(this)).safeTransfer(_from, borrowParams.amount);
            }
            revert(_getRevertMsg(reason)); //forward revert because it's handled by the main executor
        }

        emit ReceiveFromChain(_srcChainId, _from, borrowParams.amount);
    }

    function borrowInternal(
        address _from, //from
        bytes32 _to,
        ITapiocaOFT.IBorrowParams memory borrowParams,
        ICommonData.IWithdrawParams memory withdrawParams,
        ICommonData.IApproval[] memory approvals
    ) public payable {
        if (approvals.length > 0) {
            _callApproval(approvals);
        }

        // Use market helper to deposit, add collateral to market and withdrawTo
        bytes memory withdrawData = abi.encode(
            withdrawParams.withdrawOnOtherChain,
            withdrawParams.withdrawLzChainId,
            _from,
            withdrawParams.withdrawAdapterParams
        );

        approve(address(borrowParams.marketHelper), borrowParams.amount);
        IMagnetar(borrowParams.marketHelper)
            .depositAddCollateralAndBorrowFromMarket{value: msg.value}(
            borrowParams.market,
            LzLib.bytes32ToAddress(_to),
            borrowParams.amount,
            borrowParams.borrowAmount,
            true,
            true,
            withdrawParams.withdraw,
            withdrawData
        );
    }

    function remove(bytes memory _payload) public {
        (
            ,
            ,
            address to,
            ,
            ITapiocaOFT.IRemoveParams memory removeParams,
            ICommonData.IWithdrawParams memory withdrawParams,
            ICommonData.IApproval[] memory approvals
        ) = abi.decode(
                _payload,
                (
                    uint16,
                    address,
                    address,
                    bytes32,
                    ITapiocaOFT.IRemoveParams,
                    ICommonData.IWithdrawParams,
                    ICommonData.IApproval[]
                )
            );

        if (approvals.length > 0) {
            _callApproval(approvals);
        }

        approve(removeParams.market, removeParams.share);
        IMarket(removeParams.market).removeCollateral(
            to,
            to,
            removeParams.share
        );
        if (withdrawParams.withdraw) {
            address ybAddress = IMarket(removeParams.market).yieldBox();
            uint256 assetId = IMarket(removeParams.market).collateralId();
            IMagnetar(removeParams.marketHelper).withdrawToChain{
                value: withdrawParams.withdrawLzFeeAmount
            }(
                ybAddress,
                to,
                assetId,
                withdrawParams.withdrawLzChainId,
                LzLib.addressToBytes32(to),
                IYieldBoxBase(ybAddress).toAmount(
                    assetId,
                    removeParams.share,
                    false
                ),
                removeParams.share,
                withdrawParams.withdrawAdapterParams,
                payable(to),
                withdrawParams.withdrawLzFeeAmount
            );
        }
    }

    function _callApproval(ICommonData.IApproval[] memory approvals) private {
        for (uint256 i = 0; i < approvals.length; ) {
            if (approvals[i].permitBorrow) {
                try
                    IPermitBorrow(approvals[i].target).permitBorrow(
                        approvals[i].owner,
                        approvals[i].spender,
                        approvals[i].value,
                        approvals[i].deadline,
                        approvals[i].v,
                        approvals[i].r,
                        approvals[i].s
                    )
                {} catch Error(string memory reason) {
                    if (!approvals[i].allowFailure) {
                        revert(reason);
                    }
                }
            } else if (approvals[i].permitAll) {
                try
                    IPermitAll(approvals[i].target).permitAll(
                        approvals[i].owner,
                        approvals[i].spender,
                        approvals[i].deadline,
                        approvals[i].v,
                        approvals[i].r,
                        approvals[i].s
                    )
                {} catch Error(string memory reason) {
                    if (!approvals[i].allowFailure) {
                        revert(reason);
                    }
                }
            } else {
                try
                    IERC20Permit(approvals[i].target).permit(
                        approvals[i].owner,
                        approvals[i].spender,
                        approvals[i].value,
                        approvals[i].deadline,
                        approvals[i].v,
                        approvals[i].r,
                        approvals[i].s
                    )
                {} catch Error(string memory reason) {
                    if (!approvals[i].allowFailure) {
                        revert(reason);
                    }
                }
            }

            unchecked {
                ++i;
            }
        }
    }
}
