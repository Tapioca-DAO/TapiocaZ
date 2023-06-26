// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

//LZ
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol";

//TAPIOCA
import "tapioca-periph/contracts/interfaces/IPermitBorrow.sol";
import "tapioca-periph/contracts/interfaces/IPermitAll.sol";
import "tapioca-periph/contracts/interfaces/ITapiocaOptionsBroker.sol";
// import {ITapiocaOptionsBrokerCrossChain} from "tapioca-periph/contracts/interfaces/ITapiocaOptionsBroker.sol";
import "../BaseTOFTStorage.sol";

contract BaseTOFTOptionsModule is BaseTOFTStorage {
    using SafeERC20 for IERC20;

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

    function exerciseOption(
        address from,
        uint256 paymentTokenAmount,
        uint16 lzDstChainId,
        address zroPaymentAddress,
        uint256 extraGas,
        address target,
        uint256 oTAPTokenID,
        address paymentToken,
        uint256 tapAmount,
        ITapiocaOptionsBrokerCrossChain.IApproval[] memory approvals
    ) external payable {
        bytes32 toAddress = LzLib.addressToBytes32(from);

        _debitFrom(
            from,
            lzEndpoint.getChainId(),
            toAddress,
            paymentTokenAmount
        );

        bytes memory lzPayload = abi.encode(
            PT_TAP_EXERCISE,
            from,
            target,
            paymentTokenAmount,
            oTAPTokenID,
            paymentToken,
            tapAmount,
            approvals
        );

        bytes memory adapterParams = LzLib.buildDefaultAdapterParams(extraGas);

        _lzSend(
            lzDstChainId,
            lzPayload,
            payable(from),
            zroPaymentAddress,
            adapterParams,
            msg.value
        );

        emit SendToChain(lzDstChainId, from, toAddress, paymentTokenAmount);
    }

    function exercise(uint16 _srcChainId, bytes memory _payload) public {
        (
            ,
            address from,
            address target,
            uint256 paymentTokenAmount,
            uint256 oTAPTokenID,
            address paymentToken,
            uint256 tapAmount,
            ITapiocaOptionsBrokerCrossChain.IApproval[] memory approvals
        ) = abi.decode(
                _payload,
                (
                    uint16,
                    address,
                    address,
                    uint256,
                    uint256,
                    address,
                    uint256,
                    ITapiocaOptionsBrokerCrossChain.IApproval[]
                )
            );

        _creditTo(_srcChainId, from, paymentTokenAmount);

        if (approvals.length > 0) {
            _callApproval(approvals);
        }

        ITapiocaOptionsBroker(target).exerciseOption(
            oTAPTokenID,
            paymentToken,
            tapAmount
        );

        emit ReceiveFromChain(_srcChainId, from, paymentTokenAmount);
    }

    function _callApproval(
        ITapiocaOptionsBrokerCrossChain.IApproval[] memory approvals
    ) private {
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
