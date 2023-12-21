// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

//LZ
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol";

//TAPIOCA
import {IUSDOBase} from "tapioca-periph/contracts/interfaces/IUSDO.sol";

import "./TOFTCommon.sol";

contract BaseTOFTStrategyModule is TOFTCommon {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    // ************** //
    // *** ERRORS *** //
    // ************** //
    error AllowanceNotValid();

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

    /// @notice sends TOFT to a specific strategy available on another layer
    /// @param _from the sender address
    /// @param _to the receiver address
    /// @param amount the transferred amount
    /// @param assetId the destination YieldBox asset id
    /// @param lzDstChainId the destination LayerZero id
    /// @param options the operation data
    function sendToStrategy(
        address _from,
        address _to,
        uint256 amount,
        uint256 assetId,
        uint16 lzDstChainId,
        ICommonData.ISendOptions calldata options
    ) external payable {
        if (amount == 0) revert NotValid();
        bytes32 toAddress = LzLib.addressToBytes32(_to);

        (amount, ) = _removeDust(amount);
        amount = _debitFrom(_from, lzEndpoint.getChainId(), toAddress, amount);
        if (amount == 0) revert NotValid();

        bytes memory lzPayload = abi.encode(
            PT_YB_SEND_STRAT,
            LzLib.addressToBytes32(_from),
            toAddress,
            _ld2sd(amount),
            assetId,
            options.zroPaymentAddress
        );

        _checkAdapterParams(
            lzDstChainId,
            PT_YB_SEND_STRAT,
            LzLib.buildDefaultAdapterParams(options.extraGasLimit),
            options.extraGasLimit
        );

        _lzSend(
            lzDstChainId,
            lzPayload,
            payable(_from),
            options.zroPaymentAddress,
            LzLib.buildDefaultAdapterParams(options.extraGasLimit),
            msg.value
        );

        emit SendToChain(lzDstChainId, _from, toAddress, amount);
    }

    /// @notice extracts TOFT from a specific strategy available on another layer
    /// @param _from the sender address
    /// @param amount the transferred amount
    /// @param assetId the destination YieldBox asset id
    /// @param lzDstChainId the destination LayerZero id
    /// @param zroPaymentAddress LayerZero ZRO payment address
    /// @param airdropAdapterParam the LayerZero aidrop adapter params
    function retrieveFromStrategy(
        address _from,
        uint256 amount,
        uint256 assetId,
        uint16 lzDstChainId,
        address zroPaymentAddress,
        bytes memory airdropAdapterParam
    ) external payable {
        //allowance is also checked on market
        if (_from != msg.sender) {
            if (allowance(_from, msg.sender) < amount)
                revert AllowanceNotValid();
            _spendAllowance(_from, msg.sender, amount);
        }

        if (amount == 0) revert NotValid();
        bytes32 toAddress = LzLib.addressToBytes32(msg.sender);
        (amount, ) = _removeDust(amount);

        (, , uint256 airdropAmount, ) = LzLib.decodeAdapterParams(
            airdropAdapterParam
        );
        bytes memory lzPayload = abi.encode(
            PT_YB_RETRIEVE_STRAT,
            LzLib.addressToBytes32(_from),
            toAddress,
            _ld2sd(amount),
            assetId,
            zroPaymentAddress,
            airdropAmount
        );

        _checkAdapterParams(
            lzDstChainId,
            PT_YB_RETRIEVE_STRAT,
            airdropAdapterParam,
            NO_EXTRA_GAS
        );

        _lzSend(
            lzDstChainId,
            lzPayload,
            payable(msg.sender),
            zroPaymentAddress,
            airdropAdapterParam,
            msg.value
        );
        emit SendToChain(lzDstChainId, msg.sender, toAddress, amount);
    }
}
