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

import "./TOFTCommon.sol";

contract BaseTOFTLeverageModule is TOFTCommon {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

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

    function sendForLeverage(
        uint256 amount,
        address leverageFor,
        IUSDOBase.ILeverageLZData calldata lzData,
        IUSDOBase.ILeverageSwapData calldata swapData,
        IUSDOBase.ILeverageExternalContractsData calldata externalData
    ) external payable {
        if (leverageFor != msg.sender) {
            require(
                allowance(leverageFor, msg.sender) >= amount,
                "TOFT_UNAUTHORIZED"
            );
            _spendAllowance(leverageFor, msg.sender, amount);
        }

        require(
            swapData.tokenOut != address(this),
            "USDO: token out not valid"
        );
        require(swapData.tokenOut != address(this), "TOFT_token_not_valid");
        _assureMaxSlippage(amount, swapData.amountOutMin);
        if (externalData.swapper != address(0)) {
            require(
                cluster.isWhitelisted(
                    lzData.lzDstChainId,
                    externalData.swapper
                ),
                "TOFT_UNAUTHORIZED"
            ); //fail fast
        }

        bytes32 senderBytes = LzLib.addressToBytes32(msg.sender);

        (amount, ) = _removeDust(amount);
        _debitFrom(msg.sender, lzEndpoint.getChainId(), senderBytes, amount);

        (, , uint256 airdropAmount, ) = LzLib.decodeAdapterParams(
            lzData.dstAirdropAdapterParam
        );
        bytes memory lzPayload = abi.encode(
            PT_LEVERAGE_MARKET_DOWN,
            senderBytes,
            _ld2sd(amount),
            swapData,
            externalData,
            lzData,
            leverageFor,
            airdropAmount
        );

        _checkGasLimit(
            lzData.lzDstChainId,
            PT_LEVERAGE_MARKET_DOWN,
            lzData.dstAirdropAdapterParam,
            NO_EXTRA_GAS
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
    // function multiHop(bytes memory _payload) public {
    //     require(msg.sender == address(this), "TOFT_CALLER");
    //     (
    //         ,
    //         ,
    //         address from,
    //         uint64 amountSD,
    //         IUSDOBase.ILeverageSwapData memory swapData,
    //         IUSDOBase.ILeverageLZData memory lzData,
    //         IUSDOBase.ILeverageExternalContractsData memory externalData,
    //         ICommonData.IApproval[] memory approvals
    //     ) = abi.decode(
    //             _payload,
    //             (
    //                 uint16,
    //                 bytes32,
    //                 address,
    //                 uint64,
    //                 IUSDOBase.ILeverageSwapData,
    //                 IUSDOBase.ILeverageLZData,
    //                 IUSDOBase.ILeverageExternalContractsData,
    //                 ICommonData.IApproval[]
    //             )
    //         );

    //     if (approvals.length > 0) {
    //         _callApproval(approvals, PT_MARKET_MULTIHOP_SELL);
    //     }

    //     ISingularity market = ISingularity(externalData.srcMarket);
    //     uint256 share = IYieldBoxBase(market.yieldBox()).toShare(
    //         market.collateralId(),
    //         _sd2ld(amountSD),
    //         false
    //     );
    //     ISingularity(externalData.srcMarket).multiHopSellCollateral{
    //         value: address(this).balance
    //     }(from, share, true, swapData, lzData, externalData);
    // }

    function leverageDown(
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
            ,
            uint64 amountSD,
            IUSDOBase.ILeverageSwapData memory swapData,
            IUSDOBase.ILeverageExternalContractsData memory externalData,
            IUSDOBase.ILeverageLZData memory lzData,
            address leverageFor,
            uint256 airdropAmount
        ) = abi.decode(
                _payload,
                (
                    uint16,
                    bytes32,
                    uint64,
                    IUSDOBase.ILeverageSwapData,
                    IUSDOBase.ILeverageExternalContractsData,
                    IUSDOBase.ILeverageLZData,
                    address,
                    uint256
                )
            );

        uint256 amount = _sd2ld(amountSD);
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
                leverageFor,
                airdropAmount
            )
        );

        if (!success) {
            _storeAndSend(
                balanceAfter - balanceBefore >= amount,
                amount,
                leverageFor,
                reason,
                _srcChainId,
                _srcAddress,
                _nonce,
                _payload
            );
        }

        emit ReceiveFromChain(_srcChainId, leverageFor, amount);
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

    function leverageDownInternal(
        uint256 amount,
        IUSDOBase.ILeverageSwapData memory swapData,
        IUSDOBase.ILeverageExternalContractsData memory externalData,
        IUSDOBase.ILeverageLZData memory lzData,
        address leverageFor,
        uint256 airdropAmount
    ) public payable {
        ITapiocaOFT(address(this)).unwrap(address(this), amount);

        //swap to USDO
        if (externalData.swapper != address(0)) {
            require(
                cluster.isWhitelisted(0, externalData.swapper),
                "TOFT_UNAUTHORIZED"
            );
        }

        if (erc20 != address(0)) {
            //skip approvals for native gas
            IERC20(erc20).approve(externalData.swapper, 0);
            IERC20(erc20).approve(externalData.swapper, amount);
        }
        ISwapper.SwapData memory _swapperData = ISwapper(externalData.swapper)
            .buildSwapData(erc20, swapData.tokenOut, amount, 0, false, false);
        (uint256 amountOut, ) = ISwapper(externalData.swapper).swap{
            value: erc20 == address(0) ? amount : 0
        }(_swapperData, swapData.amountOutMin, address(this), swapData.data);

        //repay
        ICommonData.IApproval[] memory approvals;
        IUSDOBase(swapData.tokenOut).sendAndLendOrRepay{value: airdropAmount}(
            address(this),
            leverageFor,
            lzData.lzSrcChainId,
            lzData.zroPaymentAddress,
            IUSDOBase.ILendOrRepayParams({
                repay: true,
                depositAmount: amountOut,
                repayAmount: 0, //it will be computed automatically at the destination IUSDO call
                marketHelper: externalData.magnetar,
                market: externalData.srcMarket,
                removeCollateral: false,
                removeCollateralAmount: 0,
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
        require(_amount > 0, "TOFT_0");
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
}
