// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

//LZ
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol";

//TAPIOCA
import {IUSDOBase} from "tapioca-periph/contracts/interfaces/IUSDO.sol";
import "tapioca-periph/contracts/interfaces/ISwapper.sol";
import "tapioca-periph/contracts/interfaces/ITapiocaOFT.sol";

import "./TOFTCommon.sol";

contract BaseTOFTStrategyModule is TOFTCommon {
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
        require(amount > 0, "TOFT_0");
        bytes32 toAddress = LzLib.addressToBytes32(_to);

        (amount, ) = _removeDust(amount);
        _debitFrom(_from, lzEndpoint.getChainId(), toAddress, amount);

        bytes memory lzPayload = abi.encode(
            PT_YB_SEND_STRAT,
            LzLib.addressToBytes32(_from),
            toAddress,
            _ld2sd(amount),
            assetId,
            options.zroPaymentAddress
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
        require(amount > 0, "TOFT_0");

        bytes32 toAddress = LzLib.addressToBytes32(msg.sender);

        (amount, ) = _removeDust(amount);
        bytes memory lzPayload = abi.encode(
            PT_YB_RETRIEVE_STRAT,
            LzLib.addressToBytes32(_from),
            toAddress,
            _ld2sd(amount),
            assetId,
            zroPaymentAddress
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

    function strategyDeposit(
        address module,
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload,
        IERC20 _erc20
    ) public {
        require(validModules[module], "TOFT_MODULE");
        (, , bytes32 from, uint64 amountSD, uint256 assetId, ) = abi.decode(
            _payload,
            (uint16, bytes32, bytes32, uint64, uint256, address)
        );

        uint256 amount = _sd2ld(amountSD);
        uint256 balanceBefore = balanceOf(address(this));
        bool credited = creditedPackets[_srcChainId][_srcAddress][_nonce];
        if (!credited) {
            _creditTo(_srcChainId, address(this), amount);
            creditedPackets[_srcChainId][_srcAddress][_nonce] = true;
        }
        uint256 balanceAfter = balanceOf(address(this));

        address onBehalfOf = LzLib.bytes32ToAddress(from);
        (bool success, bytes memory reason) = module.delegatecall(
            abi.encodeWithSelector(
                this.depositToYieldbox.selector,
                assetId,
                amount,
                _erc20,
                address(this),
                onBehalfOf
            )
        );
        if (!success) {
            if (balanceAfter - balanceBefore >= amount) {
                IERC20(address(this)).safeTransfer(onBehalfOf, amount);
            }
            _storeFailedMessage(
                _srcChainId,
                _srcAddress,
                _nonce,
                _payload,
                reason
            );
        }

        emit ReceiveFromChain(_srcChainId, onBehalfOf, amount);
    }

    function depositToYieldbox(
        uint256 _assetId,
        uint256 _amount,
        IERC20 _erc20,
        address _from,
        address _to
    ) public {
        _erc20.approve(address(yieldBox), 0);
        _erc20.approve(address(yieldBox), _amount);
        yieldBox.depositAsset(_assetId, _from, _to, _amount, 0);
    }

    function strategyWithdraw(
        uint16 _srcChainId,
        bytes memory _payload
    ) public {
        (
            ,
            bytes32 from,
            ,
            uint64 amountSD,
            uint256 _assetId,
            address _zroPaymentAddress
        ) = abi.decode(
                _payload,
                (uint16, bytes32, bytes32, uint64, uint256, address)
            );

        uint256 _amount = _sd2ld(amountSD);
        address _from = LzLib.bytes32ToAddress(from);

        (_amount, ) = _retrieveFromYieldBox(
            _assetId,
            _amount,
            _from,
            address(this)
        );
        (_amount, ) = _removeDust(_amount);
        _burn(address(this), _amount);

        bytes memory lzSendBackPayload = _encodeSendPayload(
            from,
            _ld2sd(_amount)
        );
        _lzSend(
            _srcChainId,
            lzSendBackPayload,
            payable(this),
            _zroPaymentAddress,
            "",
            address(this).balance
        );
        emit SendToChain(
            _srcChainId,
            _from,
            LzLib.addressToBytes32(address(this)),
            _amount
        );

        emit ReceiveFromChain(_srcChainId, _from, _amount);
    }

    /// @notice Receive an inter-chain transaction to execute a deposit inside YieldBox.

    /// @notice Receive an inter-chain transaction to execute a deposit inside YieldBox.
    function _retrieveFromYieldBox(
        uint256 _assetId,
        uint256 _amount,
        address _from,
        address _to
    ) private returns (uint256 amountOut, uint256 shareOut) {
        (amountOut, shareOut) = yieldBox.withdraw(
            _assetId,
            _from,
            _to,
            _amount,
            0
        );
    }
}
