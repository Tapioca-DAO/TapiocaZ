// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

//LZ
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol";

//TAPIOCA
import {IUSDOBase} from "tapioca-periph/contracts/interfaces/IUSDO.sol";

import "./TOFTCommon.sol";

contract BaseTOFTLeverageModule is TOFTCommon {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    // ************** //
    // *** ERRORS *** //
    // ************** //
    error TokenNotValid();
    error AllowanceNotValid();
    error AmountTooLow();

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
        if (swapData.tokenOut == address(this)) revert TokenNotValid();
        if (swapData.amountOutMin == 0) revert AmountTooLow();
        if (externalData.swapper != address(0)) {
            if (
                !cluster.isWhitelisted(
                    lzData.lzDstChainId,
                    externalData.swapper
                )
            ) revert NotAuthorized(externalData.swapper); //fail fast
        }

        bytes32 senderBytes = LzLib.addressToBytes32(msg.sender);

        (amount, ) = _removeDust(amount);
        amount = _debitFrom(
            leverageFor,
            lzEndpoint.getChainId(),
            senderBytes,
            amount
        );
        if (amount == 0) revert NotValid();

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
        _checkAdapterParams(
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
        emit SendToChain(lzData.lzDstChainId, leverageFor, senderBytes, amount);
    }
}
