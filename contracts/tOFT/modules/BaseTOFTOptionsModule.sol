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

    function triggerSendFrom(
        uint16 lzDstChainId,
        bytes calldata airdropAdapterParams,
        address zroPaymentAddress,
        uint256 amount,
        ISendFrom.LzCallParams calldata sendFromData,
        ITapiocaOptionsBrokerCrossChain.IApproval[] calldata approvals
    ) external payable {
        bytes memory lzPayload = abi.encode(
            PT_SEND_FROM,
            msg.sender,
            amount,
            sendFromData,
            lzEndpoint.getChainId(),
            approvals
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
    
    function exerciseOption(
        ITapiocaOptionsBrokerCrossChain.IExerciseOptionsData
            calldata optionsData,
        ITapiocaOptionsBrokerCrossChain.IExerciseLZData calldata lzData,
        ITapiocaOptionsBrokerCrossChain.IExerciseLZSendTapData
            calldata tapSendData,
        ITapiocaOptionsBrokerCrossChain.IApproval[] calldata approvals
    ) external payable {
        bytes32 toAddress = LzLib.addressToBytes32(optionsData.from);

        _debitFrom(
            optionsData.from,
            lzEndpoint.getChainId(),
            toAddress,
            optionsData.paymentTokenAmount
        );

        bytes memory lzPayload = abi.encode(
            PT_TAP_EXERCISE,
            optionsData,
            tapSendData,
            approvals
        );

        bytes memory adapterParams = LzLib.buildDefaultAdapterParams(
            lzData.extraGas
        );

        _lzSend(
            lzData.lzDstChainId,
            lzPayload,
            payable(optionsData.from),
            lzData.zroPaymentAddress,
            adapterParams,
            msg.value
        );

        emit SendToChain(
            lzData.lzDstChainId,
            optionsData.from,
            toAddress,
            optionsData.paymentTokenAmount
        );
    }   

    function sendFromDestination(bytes memory _payload) public {
        (
            ,
            address from,
            uint256 amount,
            ISendFrom.LzCallParams memory callParams,
            uint16 lzDstChainId,
            ITapiocaOptionsBrokerCrossChain.IApproval[] memory approvals
        ) = abi.decode(
                _payload,
                (
                    uint16,
                    address,
                    uint256,
                    ISendFrom.LzCallParams,
                    uint16,
                    ITapiocaOptionsBrokerCrossChain.IApproval[]
                )
            );

        if (approvals.length > 0) {
            _callApproval(approvals);
        }

        ISendFrom(address(this)).sendFrom{value: address(this).balance}(
            from,
            lzDstChainId,
            LzLib.addressToBytes32(from),
            amount,
            callParams
        );

        emit ReceiveFromChain(lzDstChainId, from, 0);
    }

    function exercise(
        address module,
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) public {
        (
            ,
            ITapiocaOptionsBrokerCrossChain.IExerciseOptionsData
                memory optionsData,
            ITapiocaOptionsBrokerCrossChain.IExerciseLZSendTapData
                memory tapSendData,
            ITapiocaOptionsBrokerCrossChain.IApproval[] memory approvals
        ) = abi.decode(
                _payload,
                (
                    uint16,
                    ITapiocaOptionsBrokerCrossChain.IExerciseOptionsData,
                    ITapiocaOptionsBrokerCrossChain.IExerciseLZSendTapData,
                    ITapiocaOptionsBrokerCrossChain.IApproval[]
                )
            );

        uint256 balanceBefore = balanceOf(address(this));
        bool credited = creditedPackets[_srcChainId][_srcAddress][_nonce];
        if (!credited) {
            _creditTo(
                _srcChainId,
                address(this),
                optionsData.paymentTokenAmount
            );
            creditedPackets[_srcChainId][_srcAddress][_nonce] = true;
        }
        uint256 balanceAfter = balanceOf(address(this));

        (bool success, bytes memory reason) = module.delegatecall(
            abi.encodeWithSelector(
                this.exerciseInternal.selector,
                optionsData.from,
                optionsData.oTAPTokenID,
                optionsData.paymentToken,
                optionsData.tapAmount,
                optionsData.target,
                tapSendData,
                approvals
            )
        );

        if (!success) {
            if (
                balanceAfter - balanceBefore >= optionsData.paymentTokenAmount
            ) {
                IERC20(address(this)).safeTransfer(
                    optionsData.from,
                    optionsData.paymentTokenAmount
                );
            }
            revert(_getRevertMsg(reason)); //forward revert because it's handled by the main executor
        }

        emit ReceiveFromChain(
            _srcChainId,
            optionsData.from,
            optionsData.paymentTokenAmount
        );
    }

    function exerciseInternal(
        address from,
        uint256 oTAPTokenID,
        address paymentToken,
        uint256 tapAmount,
        address target,
        ITapiocaOptionsBrokerCrossChain.IExerciseLZSendTapData
            memory tapSendData,
        ITapiocaOptionsBrokerCrossChain.IApproval[] memory approvals
    ) public {
        if (approvals.length > 0) {
            _callApproval(approvals);
        }

        ITapiocaOptionsBroker(target).exerciseOption(
            oTAPTokenID,
            paymentToken,
            tapAmount
        );
        if (tapSendData.withdrawOnAnotherChain) {
            ISendFrom(tapSendData.tapOftAddress).sendFrom(
                address(this),
                tapSendData.lzDstChainId,
                LzLib.addressToBytes32(from),
                tapAmount,
                ISendFrom.LzCallParams({
                    refundAddress: payable(from),
                    zroPaymentAddress: tapSendData.zroPaymentAddress,
                    adapterParams: LzLib.buildDefaultAdapterParams(
                        tapSendData.extraGas
                    )
                })
            );
        } else {
            IERC20(tapSendData.tapOftAddress).safeTransfer(from, tapAmount);
        }
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
