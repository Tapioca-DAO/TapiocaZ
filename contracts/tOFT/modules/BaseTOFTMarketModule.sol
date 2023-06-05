// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

//LZ
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol";

//TAPIOCA
import {IUSDOBase} from "tapioca-periph/contracts/interfaces/IUSDO.sol";
import "tapioca-periph/contracts/interfaces/ISwapper.sol";
import "tapioca-periph/contracts/interfaces/ITapiocaOFT.sol";
import "tapioca-periph/contracts/interfaces/IMagnetar.sol";
import "tapioca-periph/contracts/interfaces/IPermitBorrow.sol";

import "./BaseTOFTModule.sol";

contract BaseTOFTMarketModule is BaseTOFTModule {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    // ************ //
    // *** VARS *** //
    // ************ //
    uint16 constant PT_YB_SEND_SGL_BORROW = 775;

    constructor(
        address _lzEndpoint,
        address _erc20,
        IYieldBoxBase _yieldBox,
        string memory _name,
        string memory _symbol,
        uint8 _decimal,
        uint256 _hostChainID
    )
        BaseTOFTModule(
            _lzEndpoint,
            _erc20,
            _yieldBox,
            _name,
            _symbol,
            _decimal,
            _hostChainID
        )
    {}

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
        ITapiocaOFT.IWithdrawParams calldata withdrawParams,
        ITapiocaOFT.ISendOptions calldata options,
        ITapiocaOFT.IApproval[] calldata approvals
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

    function borrow(uint16 _srcChainId, bytes memory _payload) public payable {
        (
            ,
            address _from, //from
            bytes32 _to,
            ITapiocaOFT.IBorrowParams memory borrowParams,
            ITapiocaOFT.IWithdrawParams memory withdrawParams,
            ITapiocaOFT.IApproval[] memory approvals
        ) = abi.decode(
                _payload,
                (
                    uint16,
                    address,
                    bytes32,
                    ITapiocaOFT.IBorrowParams,
                    ITapiocaOFT.IWithdrawParams,
                    ITapiocaOFT.IApproval[]
                )
            );

        if (approvals.length > 0) {
            _callApproval(approvals);
        }
        _creditTo(_srcChainId, address(this), borrowParams.amount);

        // Use market helper to deposit, add collateral to market and withdrawTo
        bytes memory withdrawData = abi.encode(
            withdrawParams.withdrawOnOtherChain,
            withdrawParams.withdrawLzChainId,
            _from,
            withdrawParams.withdrawAdapterParams
        );

        approve(address(borrowParams.marketHelper), borrowParams.amount);
        IMagnetar(borrowParams.marketHelper).depositAddCollateralAndBorrow{
            value: msg.value
        }(
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

    function _callApproval(ITapiocaOFT.IApproval[] memory approvals) private {
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