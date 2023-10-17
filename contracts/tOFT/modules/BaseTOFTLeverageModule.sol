// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

//LZ
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol";

//TAPIOCA
import {IUSDOBase} from "tapioca-periph/contracts/interfaces/IUSDO.sol";

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

    function initMultiSell(
        address from,
        uint256 amount,
        IUSDOBase.ILeverageSwapData calldata swapData,
        IUSDOBase.ILeverageLZData calldata lzData,
        IUSDOBase.ILeverageExternalContractsData calldata externalData,
        bytes calldata airdropAdapterParams,
        ICommonData.IApproval[] calldata approvals
    ) external payable {
        //allowance is also checked on market
        if (from != msg.sender) {
            require(allowance(from, msg.sender) >= amount, "TOFT_UNAUTHORIZED");
            _spendAllowance(from, msg.sender, amount);
        }

        _assureMaxSlippage(amount, swapData.amountOutMin);
        bytes32 senderBytes = LzLib.addressToBytes32(from);

        (amount, ) = _removeDust(amount);
        bytes memory lzPayload = abi.encode(
            PT_MARKET_MULTIHOP_SELL,
            senderBytes,
            from,
            _ld2sd(amount),
            swapData,
            lzData,
            externalData,
            airdropAdapterParams,
            approvals
        );

        _checkGasLimit(
            lzData.lzSrcChainId,
            PT_MARKET_MULTIHOP_SELL,
            airdropAdapterParams,
            NO_EXTRA_GAS
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
}
