// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

//LZ
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol";

//TAPIOCA
import {IUSDOBase} from "tapioca-periph/contracts/interfaces/IUSDO.sol";
import "tapioca-periph/contracts/interfaces/ISwapper.sol";
import "tapioca-periph/contracts/interfaces/IMagnetar.sol";
import "tapioca-periph/contracts/interfaces/ISingularity.sol";
import "tapioca-periph/contracts/interfaces/IPermitBorrow.sol";
import "tapioca-periph/contracts/interfaces/IPermitAll.sol";
import "tapioca-periph/contracts/interfaces/ITapiocaOptionsBroker.sol";
import "tapioca-periph/contracts/interfaces/ITapiocaOptionLiquidityProvision.sol";

import "../BaseTOFTStorage.sol";

contract BaseTOFTLeverageModule is BaseTOFTStorage {
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

    function initMultiSell(
        address from,
        uint256 share,
        IUSDOBase.ILeverageSwapData calldata swapData,
        IUSDOBase.ILeverageLZData calldata lzData,
        IUSDOBase.ILeverageExternalContractsData calldata externalData,
        bytes calldata airdropAdapterParams,
        ICommonData.IApproval[] calldata approvals
    ) external payable {
        bytes32 senderBytes = LzLib.addressToBytes32(from);

        bytes memory lzPayload = abi.encode(
            PT_MARKET_MULTIHOP_SELL,
            senderBytes,
            from,
            share,
            swapData,
            lzData,
            externalData,
            airdropAdapterParams,
            approvals
        );

        _lzSend(
            lzData.lzSrcChainId,
            lzPayload,
            payable(lzData.refundAddress),
            lzData.zroPaymentAddress,
            airdropAdapterParams,
            msg.value
        );
        emit SendToChain(lzData.lzSrcChainId, msg.sender, senderBytes, 0);
    }

    function sendForLeverage(
        uint256 amount,
        address leverageFor,
        IUSDOBase.ILeverageLZData calldata lzData,
        IUSDOBase.ILeverageSwapData calldata swapData,
        IUSDOBase.ILeverageExternalContractsData calldata externalData
    ) external payable {
        bytes32 senderBytes = LzLib.addressToBytes32(msg.sender);
        _debitFrom(msg.sender, lzEndpoint.getChainId(), senderBytes, amount);

        bytes memory lzPayload = abi.encode(
            PT_LEVERAGE_MARKET_DOWN,
            senderBytes,
            amount,
            swapData,
            externalData,
            lzData,
            leverageFor
        );

        _lzSend(
            lzData.lzDstChainId,
            lzPayload,
            payable(lzData.refundAddress),
            lzData.zroPaymentAddress,
            lzData.dstAirdropAdapterParam,
            msg.value
        );
        emit SendToChain(lzData.lzDstChainId, msg.sender, senderBytes, amount);
    }

    //---Destination calls---
    function multiHop(bytes memory _payload) public {
        (
            ,
            ,
            address from,
            uint256 share,
            IUSDOBase.ILeverageSwapData memory swapData,
            IUSDOBase.ILeverageLZData memory lzData,
            IUSDOBase.ILeverageExternalContractsData memory externalData,
            ICommonData.IApproval[] memory approvals
        ) = abi.decode(
                _payload,
                (
                    uint16,
                    bytes32,
                    address,
                    uint256,
                    IUSDOBase.ILeverageSwapData,
                    IUSDOBase.ILeverageLZData,
                    IUSDOBase.ILeverageExternalContractsData,
                    ICommonData.IApproval[]
                )
            );

        if (approvals.length > 0) {
            _callApproval(approvals);
        }

        ISingularity(externalData.srcMarket).multiHopSellCollateral(
            from,
            share,
            swapData,
            lzData,
            externalData
        );
    }

    function leverageDown(
        address module,
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) public {
        (
            ,
            ,
            uint256 amount,
            IUSDOBase.ILeverageSwapData memory swapData,
            IUSDOBase.ILeverageExternalContractsData memory externalData,
            IUSDOBase.ILeverageLZData memory lzData,
            address leverageFor
        ) = abi.decode(
                _payload,
                (
                    uint16,
                    bytes32,
                    uint256,
                    IUSDOBase.ILeverageSwapData,
                    IUSDOBase.ILeverageExternalContractsData,
                    IUSDOBase.ILeverageLZData,
                    address
                )
            );

        uint256 balanceBefore = balanceOf(address(this));
        bool credited = creditedPackets[_srcChainId][_srcAddress][_nonce];
        if (!credited) {
            _creditTo(_srcChainId, address(this), amount);
            creditedPackets[_srcChainId][_srcAddress][_nonce] = true;
        }
        uint256 balanceAfter = balanceOf(address(this));

        (bool success, bytes memory reason) = module.delegatecall(
            abi.encodeWithSelector(
                this.leverageDownInternal.selector,
                amount,
                swapData,
                externalData,
                lzData,
                leverageFor
            )
        );

        if (!success) {
            if (balanceAfter - balanceBefore >= amount) {
                IERC20(address(this)).safeTransfer(leverageFor, amount);
            }
            revert(_getRevertMsg(reason)); //forward revert because it's handled by the main executor
        }

        emit ReceiveFromChain(_srcChainId, leverageFor, amount);
    }

    function leverageDownInternal(
        uint256 amount,
        IUSDOBase.ILeverageSwapData memory swapData,
        IUSDOBase.ILeverageExternalContractsData memory externalData,
        IUSDOBase.ILeverageLZData memory lzData,
        address leverageFor
    ) public payable {
        _unwrap(address(this), amount);

        //swap to USDO
        IERC20(erc20).approve(externalData.swapper, amount);
        ISwapper.SwapData memory _swapperData = ISwapper(externalData.swapper)
            .buildSwapData(erc20, swapData.tokenOut, amount, 0, false, false);
        (uint256 amountOut, ) = ISwapper(externalData.swapper).swap(
            _swapperData,
            swapData.amountOutMin,
            address(this),
            swapData.data
        );

        //repay
        uint256 repayableAmount = IMagnetar(externalData.magnetar)
            .getBorrowPartForAmount(externalData.srcMarket, amountOut);
        ICommonData.IApproval[] memory approvals;
        IUSDOBase(swapData.tokenOut).sendAndLendOrRepay{
            value: address(this).balance
        }(
            address(this),
            leverageFor,
            lzData.lzSrcChainId,
            lzData.zroPaymentAddress,
            IUSDOBase.ILendOrRepayParams({
                repay: true,
                depositAmount: amountOut,
                repayAmount: repayableAmount,
                marketHelper: externalData.magnetar,
                market: externalData.srcMarket,
                removeCollateral: false,
                removeCollateralShare: 0,
                lockData: ITapiocaOptionLiquidityProvision.IOptionsLockData({
                    lock: false,
                    target: address(0),
                    lockDuration: 0,
                    amount: 0,
                    fraction: 0
                }),
                participateData: ITapiocaOptionsBroker.IOptionsParticipateData({
                    participate: false,
                    target: address(0),
                    tOLPTokenId: 0
                })
            }),
            approvals,
            ICommonData.IWithdrawParams({
                withdraw: false,
                withdrawLzFeeAmount: 0,
                withdrawOnOtherChain: false,
                withdrawLzChainId: 0,
                withdrawAdapterParams: "0x"
            }),
            LzLib.buildDefaultAdapterParams(lzData.srcExtraGasLimit)
        );
    }

    function _unwrap(address _toAddress, uint256 _amount) private {
        _burn(msg.sender, _amount);

        if (erc20 == address(0)) {
            _safeTransferETH(_toAddress, _amount);
        } else {
            IERC20(erc20).safeTransfer(_toAddress, _amount);
        }
    }

    function _safeTransferETH(address to, uint256 amount) private {
        (bool sent, ) = to.call{value: amount}("");
        require(sent, "TOFT_failed");
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
