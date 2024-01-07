// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

//LZ
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol";

//TAPIOCA
import "tapioca-periph/contracts/interfaces/IPermitBorrow.sol";
import "tapioca-periph/contracts/interfaces/IPermitAll.sol";
import "tapioca-periph/contracts/interfaces/ITapiocaOptionsBroker.sol";

import "./TOFTCommon.sol";

contract BaseTOFTOptionsDestinationModule is TOFTCommon {
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

    function exercise(
        address module,
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) public {
        if (
            msg.sender != address(this) ||
            _moduleAddresses[Module.OptionsDestination] != module
        ) revert ModuleNotAuthorized();
        (
            ,
            uint64 amountSD,
            ITapiocaOptionsBrokerCrossChain.IExerciseOptionsData
                memory optionsData,
            ITapiocaOptionsBrokerCrossChain.IExerciseLZSendTapData
                memory tapSendData,
            ICommonData.IApproval[] memory approvals,
            ICommonData.IApproval[] memory revokes,
            uint256 airdropAmount
        ) = abi.decode(
                _payload,
                (
                    uint16,
                    uint64,
                    ITapiocaOptionsBrokerCrossChain.IExerciseOptionsData,
                    ITapiocaOptionsBrokerCrossChain.IExerciseLZSendTapData,
                    ICommonData.IApproval[],
                    ICommonData.IApproval[],
                    uint256
                )
            );

        if (tapSendData.tapOftAddress != address(0)) {
            if (!cluster.isWhitelisted(0, tapSendData.tapOftAddress))
                revert NotAuthorized(tapSendData.tapOftAddress); //fail fast
        }

        if (optionsData.target != address(0)) {
            if (!cluster.isWhitelisted(0, optionsData.target))
                revert NotAuthorized(optionsData.target); //fail fast
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
                module,
                optionsData.from,
                optionsData.oTAPTokenID,
                address(this),
                optionsData.tapAmount,
                optionsData.target,
                tapSendData,
                optionsData.paymentTokenAmount,
                approvals,
                revokes,
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
        address module,
        address from,
        uint256 oTAPTokenID,
        address paymentToken,
        uint256 tapAmount,
        address target,
        ITapiocaOptionsBrokerCrossChain.IExerciseLZSendTapData
            memory tapSendData,
        uint256 paymentTokenAmount,
        ICommonData.IApproval[] memory approvals,
        ICommonData.IApproval[] memory revokes,
        uint256 airdropAmount
    ) public {
        if (
            msg.sender != address(this) ||
            _moduleAddresses[Module.OptionsDestination] != module
        ) revert ModuleNotAuthorized();

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
            uint256 amountToSend = tapSendData.amount > tapAmount
                ? tapAmount
                : tapSendData.amount;
            ISendFrom(tapSendData.tapOftAddress).sendFrom{value: airdropAmount}(
                address(this),
                tapSendData.lzDstChainId,
                LzLib.addressToBytes32(from),
                amountToSend,
                LzCallParams({
                    refundAddress: payable(from),
                    zroPaymentAddress: tapSendData.zroPaymentAddress,
                    adapterParams: LzLib.buildDefaultAdapterParams(
                        tapSendData.extraGas
                    )
                })
            );
            if (tapAmount - amountToSend > 0) {
                IERC20(tapSendData.tapOftAddress).safeTransfer(
                    from,
                    tapAmount - amountToSend
                );
            }
        } else {
            IERC20(tapSendData.tapOftAddress).safeTransfer(from, tapAmount);
        }

        if (revokes.length > 0) {
            _callApproval(revokes, PT_TAP_EXERCISE);
        }
    }
}
