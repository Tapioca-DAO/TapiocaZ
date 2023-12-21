// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

//LZ
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol";

//TAPIOCA
import {IUSDOBase} from "tapioca-periph/contracts/interfaces/IUSDO.sol";

import "./TOFTCommon.sol";

contract BaseTOFTStrategyDestinationModule is TOFTCommon {
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

    function strategyDeposit(
        address module,
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) public {
        if (
            msg.sender != address(this) ||
            _moduleAddresses[Module.StrategyDestination] != module
        ) revert ModuleNotAuthorized();
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
                module,
                yieldBox,
                assetId,
                amount,
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
        address module,
        IYieldBoxBase _yieldBox,
        uint256 _assetId,
        uint256 _amount,
        address _from,
        address _to
    ) public {
        if (
            msg.sender != address(this) ||
            _moduleAddresses[Module.StrategyDestination] != module
        ) revert ModuleNotAuthorized();
        IERC20(address(this)).approve(address(_yieldBox), 0);
        IERC20(address(this)).approve(address(_yieldBox), _amount);
        uint256 share = _yieldBox.toShare(_assetId, _amount, false);
        _yieldBox.depositAsset(_assetId, _from, _to, 0, share);
    }

    function strategyWithdraw(
        address,
        uint16 _srcChainId,
        bytes memory,
        uint64,
        bytes memory _payload
    ) public {
        if (msg.sender != address(this)) revert NotAuthorized(address(this));
        (
            ,
            bytes32 from,
            ,
            uint64 amountSD,
            uint256 _assetId,
            address _zroPaymentAddress,
            uint256 airdropAmount
        ) = abi.decode(
                _payload,
                (uint16, bytes32, bytes32, uint64, uint256, address, uint256)
            );

        uint256 _amount = _sd2ld(amountSD);
        address _from = LzLib.bytes32ToAddress(from);

        (_amount, ) = _retrieveFromYieldBox(
            _assetId,
            _amount,
            _from,
            address(this),
            yieldBox
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
            payable(_from),
            _zroPaymentAddress,
            "",
            airdropAmount
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
    function _retrieveFromYieldBox(
        uint256 _assetId,
        uint256 _amount,
        address _from,
        address _to,
        IYieldBoxBase _yieldBox
    ) private returns (uint256 amountOut, uint256 shareOut) {
        if (msg.sender != address(this)) revert NotAuthorized(address(this));
        (amountOut, shareOut) = _yieldBox.withdraw(
            _assetId,
            _from,
            _to,
            _amount,
            0
        );
    }
}
