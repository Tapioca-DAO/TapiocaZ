// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

//LZ
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol";

//TAPIOCA
import "tapioca-periph/contracts/interfaces/IPermitBorrow.sol";
import "tapioca-periph/contracts/interfaces/IPermitAll.sol";
import "tapioca-periph/contracts/interfaces/ITapiocaOptionsBroker.sol";

import "./TOFTCommon.sol";

contract BaseTOFTOptionsModule is TOFTCommon {
    using SafeERC20 for IERC20;

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

    function triggerSendFrom(
        uint16 lzDstChainId,
        bytes calldata airdropAdapterParams,
        address zroPaymentAddress,
        uint256 amount,
        ISendFrom.LzCallParams calldata sendFromData,
        ICommonData.IApproval[] calldata approvals
    ) external payable {
        (, , uint256 airdropAmount, ) = LzLib.decodeAdapterParams(
            airdropAdapterParams
        );

        (amount, ) = _removeDust(amount);
        bytes memory lzPayload = abi.encode(
            PT_SEND_FROM,
            msg.sender,
            _ld2sd(amount),
            sendFromData,
            lzEndpoint.getChainId(),
            approvals,
            airdropAmount
        );

        _checkGasLimit(
            lzDstChainId,
            PT_SEND_FROM,
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

    function exerciseOption(
        ITapiocaOptionsBrokerCrossChain.IExerciseOptionsData memory optionsData,
        ITapiocaOptionsBrokerCrossChain.IExerciseLZData calldata lzData,
        ITapiocaOptionsBrokerCrossChain.IExerciseLZSendTapData
            calldata tapSendData,
        ICommonData.IApproval[] calldata approvals,
        bytes calldata adapterParams
    ) external payable {
        if (tapSendData.tapOftAddress != address(0)) {
            require(
                cluster.isWhitelisted(
                    lzData.lzDstChainId,
                    tapSendData.tapOftAddress
                ),
                "TOFT_UNAUTHORIZED"
            ); //fail fast
        }

        // allowance is also checked on SGL
        // check it here as well because tokens are moved over layers
        if (optionsData.from != msg.sender) {
            require(
                allowance(optionsData.from, msg.sender) >=
                    optionsData.paymentTokenAmount,
                "TOFT_UNAUTHORIZED"
            );
            _spendAllowance(
                optionsData.from,
                msg.sender,
                optionsData.paymentTokenAmount
            );
        }

        bytes32 toAddress = LzLib.addressToBytes32(optionsData.from);

        (uint256 paymentTokenAmount, ) = _removeDust(
            optionsData.paymentTokenAmount
        );
        _debitFrom(
            optionsData.from,
            lzEndpoint.getChainId(),
            toAddress,
            paymentTokenAmount
        );
        (, , uint256 airdropAmount, ) = LzLib.decodeAdapterParams(
            adapterParams
        );
        bytes memory lzPayload = abi.encode(
            PT_TAP_EXERCISE,
            _ld2sd(paymentTokenAmount),
            optionsData,
            tapSendData,
            approvals,
            airdropAmount
        );

        _checkGasLimit(
            lzData.lzDstChainId,
            PT_TAP_EXERCISE,
            adapterParams,
            NO_EXTRA_GAS
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
            uint64 amount,
            ISendFrom.LzCallParams memory callParams,
            uint16 lzDstChainId,
            ICommonData.IApproval[] memory approvals,
            uint256 airdropAmount
        ) = abi.decode(
                _payload,
                (
                    uint16,
                    address,
                    uint64,
                    ISendFrom.LzCallParams,
                    uint16,
                    ICommonData.IApproval[],
                    uint256
                )
            );

        if (approvals.length > 0) {
            _callApproval(approvals, PT_SEND_FROM);
        }

        ISendFrom(address(this)).sendFrom{value: airdropAmount}(
            from,
            lzDstChainId,
            LzLib.addressToBytes32(from),
            _sd2ld(amount),
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
        require(msg.sender == address(this), "TOFT_CALLER");
        require(validModules[module], "TOFT_MODULE");
        (
            ,
            uint64 amountSD,
            ITapiocaOptionsBrokerCrossChain.IExerciseOptionsData
                memory optionsData,
            ITapiocaOptionsBrokerCrossChain.IExerciseLZSendTapData
                memory tapSendData,
            ICommonData.IApproval[] memory approvals,
            uint256 airdropAmount
        ) = abi.decode(
                _payload,
                (
                    uint16,
                    uint64,
                    ITapiocaOptionsBrokerCrossChain.IExerciseOptionsData,
                    ITapiocaOptionsBrokerCrossChain.IExerciseLZSendTapData,
                    ICommonData.IApproval[],
                    uint256
                )
            );

        if (tapSendData.tapOftAddress != address(0)) {
            require(
                cluster.isWhitelisted(0, tapSendData.tapOftAddress),
                "TOFT_UNAUTHORIZED"
            ); //fail fast
        }

        optionsData.paymentTokenAmount = _sd2ld(amountSD);
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
                optionsData.paymentTokenAmount,
                approvals,
                airdropAmount
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
            _storeFailedMessage(
                _srcChainId,
                _srcAddress,
                _nonce,
                _payload,
                reason
            );
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
        uint256 paymentTokenAmount,
        ICommonData.IApproval[] memory approvals,
        uint256 airdropAmount
    ) public {
        if (approvals.length > 0) {
            _callApproval(approvals, PT_TAP_EXERCISE);
        }

        uint256 paymentTokenBalanceBefore = IERC20(paymentToken).balanceOf(
            address(this)
        );
        ITapiocaOptionsBroker(target).exerciseOption(
            oTAPTokenID,
            paymentToken,
            tapAmount
        );
        uint256 paymentTokenBalanceAfter = IERC20(paymentToken).balanceOf(
            address(this)
        );

        if (paymentTokenBalanceBefore > paymentTokenBalanceAfter) {
            uint256 diff = paymentTokenBalanceBefore - paymentTokenBalanceAfter;
            if (diff < paymentTokenAmount) {
                uint256 toReturn = paymentTokenAmount - diff;
                IERC20(paymentToken).safeTransfer(from, toReturn);
            }
        }
        if (tapSendData.withdrawOnAnotherChain) {
            ISendFrom(tapSendData.tapOftAddress).sendFrom{value: airdropAmount}(
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
}
