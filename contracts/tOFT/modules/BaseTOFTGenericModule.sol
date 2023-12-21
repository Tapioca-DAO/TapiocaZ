// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

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

    function triggerSendFromWithParams(
        address from,
        uint16 lzDstChainId,
        bytes32 toAddress,
        uint256 amount,
        ICommonOFT.LzCallParams calldata callParams,
        bool unwrap,
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
            payable(msg.sender),
            callParams.zroPaymentAddress,
            callParams.adapterParams,
            msg.value
        );

        emit SendToChain(lzDstChainId, from, toAddress, amount);
    }

    /// @dev destination call for BaseTOFTGenericModule.triggerSendFromWithParams
    function executSendFromWithParams(
        address,
        uint16 lzSrcChainId,
        bytes memory,
        uint64,
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

        amount = _creditTo(
            lzSrcChainId,
            unwrap ? address(this) : toAddress,
            amount
        );
        if (unwrap) {
            ITapiocaOFTBase tOFT = ITapiocaOFTBase(address(this));
            address toftERC20 = tOFT.erc20();

            tOFT.unwrap(address(this), amount);

            if (toftERC20 != address(0)) {
                IERC20(toftERC20).safeTransfer(toAddress, amount);
            } else {
                (bool sent, ) = toAddress.call{value: amount}("");
                if (!sent) revert Failed();
            }
        }

        if (revokes.length > 0) {
            _callApproval(revokes, PT_SEND_FROM_PARAMS);
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
            payable(msg.sender),
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
        uint16 lzDstChainId,
        bytes calldata airdropAdapterParams,
        address zroPaymentAddress,
        uint256 amount,
        ICommonOFT.LzCallParams calldata sendFromData,
        ICommonData.IApproval[] calldata approvals,
        ICommonData.IApproval[] calldata revokes
    ) external payable {
        (, , uint256 airdropAmount, ) = LzLib.decodeAdapterParams(
            airdropAdapterParams
        );

        (amount, ) = _removeDust(amount);
        bytes memory lzPayload = abi.encode(
            PT_TRIGGER_SEND_FROM,
            msg.sender,
            _ld2sd(amount),
            sendFromData,
            lzEndpoint.getChainId(),
            approvals,
            revokes,
            airdropAmount
        );

        _checkAdapterParams(
            lzDstChainId,
            PT_TRIGGER_SEND_FROM,
            airdropAdapterParams,
            NO_EXTRA_GAS
        );

        _lzSend(
            lzDstChainId,
            lzPayload,
            payable(msg.sender),
            zroPaymentAddress,
            airdropAdapterParams,
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
            LzLib.addressToBytes32(from),
            _sd2ld(amount),
            callParams
        );

        if (revokes.length > 0) {
            _callApproval(revokes, PT_TRIGGER_SEND_FROM);
        }

        emit ReceiveFromChain(lzDstChainId, from, 0);
    }
}
