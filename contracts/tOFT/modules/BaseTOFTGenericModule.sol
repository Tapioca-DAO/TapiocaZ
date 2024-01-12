// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

//LZ
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol";
import {ICommonOFT} from "tapioca-sdk/dist/contracts/token/oft/v2/ICommonOFT.sol";

//TAPIOCA
import "tapioca-periph/contracts/interfaces/ISendFrom.sol";

import "./TOFTCommon.sol";

contract BaseTOFTGenericModule is TOFTCommon {
    using SafeERC20 for IERC20;

    // ************** //
    // *** ERRORS *** //
    // ************** //
    error AllowanceNotValid();
    error Failed();

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

    function sendFromWithParams(
        address from,
        uint16 lzDstChainId,
        bytes32 toAddress,
        uint256 amount,
        ICommonOFT.LzCallParams calldata callParams,
        bool unwrap,
        ICommonData.IApproval[] calldata approvals,
        ICommonData.IApproval[] calldata revokes
    ) external payable {
        _checkAdapterParams(
            lzDstChainId,
            PT_SEND_FROM_PARAMS,
            callParams.adapterParams,
            NO_EXTRA_GAS
        );

        (amount, ) = _removeDust(amount);
        amount = _debitFrom(from, lzDstChainId, toAddress, amount);
        if (amount == 0) revert NotValid();
        bytes memory lzPayload = abi.encode(
            PT_SEND_FROM_PARAMS,
            toAddress,
            _ld2sd(amount),
            unwrap,
            approvals,
            revokes
        );
        _lzSend(
            lzDstChainId,
            lzPayload,
            callParams.refundAddress,
            callParams.zroPaymentAddress,
            callParams.adapterParams,
            msg.value
        );

        emit SendToChain(lzDstChainId, from, toAddress, amount);
    }

    /// @dev destination call for BaseTOFTGenericModule.sendFromWithParams
    function executSendFromWithParams(
        address,
        uint16 lzSrcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) public {
        if (msg.sender != address(this)) revert NotAuthorized(address(this));
        (
            ,
            bytes32 to,
            uint64 amountSD,
            bool unwrap,
            ICommonData.IApproval[] memory approvals,
            ICommonData.IApproval[] memory revokes
        ) = abi.decode(
                _payload,
                (
                    uint16,
                    bytes32,
                    uint64,
                    bool,
                    ICommonData.IApproval[],
                    ICommonData.IApproval[]
                )
            );
        if (approvals.length > 0) {
            _callApproval(approvals, PT_SEND_FROM_PARAMS);
        }

        address toAddress = LzLib.bytes32ToAddress(to);
        uint256 amount = _sd2ld(amountSD);

        bool credited = creditedPackets[lzSrcChainId][_srcAddress][_nonce];
        if (!credited) {
            amount = _creditTo(
                lzSrcChainId,
                unwrap ? address(this) : toAddress,
                amount
            );
            creditedPackets[lzSrcChainId][_srcAddress][_nonce] = true;
        }

        ITapiocaOFTBase tOFT = ITapiocaOFTBase(address(this));
        address toftERC20 = tOFT.erc20();
        if (unwrap) {
            tOFT.unwrap(address(this), amount);
        }

        if (revokes.length > 0) {
            _callApproval(revokes, PT_SEND_FROM_PARAMS);
        }

        // moved here to respect CEI and protect from a re-entrancy attack
        if (unwrap) {
            if (toftERC20 != address(0)) {
                IERC20(toftERC20).safeTransfer(toAddress, amount);
            } else {
                (bool sent, ) = toAddress.call{value: amount}("");
                if (!sent) revert Failed();
            }
        }

        emit ReceiveFromChain(lzSrcChainId, toAddress, amount);
    }

    function triggerApproveOrRevoke(
        uint16 lzDstChainId,
        ICommonOFT.LzCallParams calldata lzCallParams,
        ICommonData.IApproval[] calldata approvals
    ) external payable {
        bytes memory lzPayload = abi.encode(PT_APPROVE, msg.sender, approvals);

        _checkAdapterParams(
            lzDstChainId,
            PT_APPROVE,
            lzCallParams.adapterParams,
            NO_EXTRA_GAS
        );

        _lzSend(
            lzDstChainId,
            lzPayload,
            lzCallParams.refundAddress,
            lzCallParams.zroPaymentAddress,
            lzCallParams.adapterParams,
            msg.value
        );

        emit SendToChain(
            lzDstChainId,
            msg.sender,
            LzLib.addressToBytes32(msg.sender),
            0
        );
    }

    /// @dev destination call for `BaseTOFTGenericModule.triggerApproveOrRevoke`
    function executeApproval(
        address,
        uint16 lzSrcChainId,
        bytes memory,
        uint64,
        bytes memory _payload
    ) public {
        if (msg.sender != address(this)) revert NotAuthorized(address(this));
        (, address from, ICommonData.IApproval[] memory approvals) = abi.decode(
            _payload,
            (uint16, address, ICommonData.IApproval[])
        );

        if (approvals.length > 0) {
            _callApproval(approvals, PT_APPROVE);
        }

        emit ReceiveFromChain(lzSrcChainId, from, 0);
    }

    function triggerSendFrom(
        address from,
        uint16 lzDstChainId,
        bytes32 to,
        uint256 amount,
        ICommonOFT.LzCallParams calldata sendFromData,
        ICommonData.IApproval[] calldata approvals,
        ICommonData.IApproval[] calldata revokes
    ) external payable {
        if (from != msg.sender) {
            if (allowance(from, msg.sender) < amount)
                revert AllowanceNotValid();
            _spendAllowance(from, msg.sender, amount);
        }

        _checkAdapterParams(
            lzDstChainId,
            PT_TRIGGER_SEND_FROM,
            sendFromData.adapterParams,
            NO_EXTRA_GAS
        );

        (amount, ) = _removeDust(amount);
        if (amount == 0) revert NotValid();

        (, , uint256 airdropAmount, ) = LzLib.decodeAdapterParams(
            sendFromData.adapterParams
        );

        bytes memory lzPayload = abi.encode(
            PT_TRIGGER_SEND_FROM,
            from,
            to,
            _ld2sd(amount),
            sendFromData,
            lzEndpoint.getChainId(),
            approvals,
            revokes,
            airdropAmount
        );

        _lzSend(
            lzDstChainId,
            lzPayload,
            sendFromData.refundAddress,
            sendFromData.zroPaymentAddress,
            sendFromData.adapterParams,
            msg.value
        );

        emit SendToChain(
            lzDstChainId,
            msg.sender,
            LzLib.addressToBytes32(msg.sender),
            0
        );
    }

    /// @dev destination call for BaseTOFTGenericModule.triggerSendFrom
    function sendFromDestination(bytes memory _payload) public {
        if (msg.sender != address(this)) revert NotAuthorized(address(this));
        (
            ,
            address from,
            bytes32 to,
            uint64 amount,
            ICommonOFT.LzCallParams memory callParams,
            uint16 lzDstChainId,
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
                    ICommonOFT.LzCallParams,
                    uint16,
                    ICommonData.IApproval[],
                    ICommonData.IApproval[],
                    uint256
                )
            );

        if (approvals.length > 0) {
            _callApproval(approvals, PT_TRIGGER_SEND_FROM);
        }

        ISendFrom(address(this)).sendFrom{value: airdropAmount}(
            from,
            lzDstChainId,
            to,
            _sd2ld(amount),
            callParams
        );

        if (revokes.length > 0) {
            _callApproval(revokes, PT_TRIGGER_SEND_FROM);
        }

        emit ReceiveFromChain(lzDstChainId, from, 0);
    }
}
