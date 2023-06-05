// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

//LZ
import "tapioca-sdk/dist/contracts/token/oft/v2/OFTV2.sol";

//OZ
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

//TAPIOCA
import "tapioca-periph/contracts/interfaces/IYieldBoxBase.sol";
import "tapioca-periph/contracts/interfaces/IMagnetar.sol";
import "tapioca-periph/contracts/interfaces/IPermitBorrow.sol";
import {IUSDOBase} from "tapioca-periph/contracts/interfaces/IUSDO.sol";
import "tapioca-periph/contracts/interfaces/ISwapper.sol";

abstract contract BaseTOFT is OFTV2, ERC20Permit {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    // ************ //
    // *** VARS *** //
    // ************ //
    /// @notice The YieldBox address.
    IYieldBoxBase public yieldBox;

    uint16 constant PT_YB_SEND_STRAT = 770;
    uint16 constant PT_YB_RETRIEVE_STRAT = 771;
    uint16 constant PT_YB_SEND_SGL_BORROW = 775;
    uint16 constant PT_LEVERAGE_MARKET_DOWN = 776;

    /// @notice The ERC20 to wrap.
    address public erc20;
    /// @notice The host chain ID of the ERC20
    uint256 public hostChainID;
    /// @notice Decimal cache number of the ERC20.
    uint8 internal _decimalCache;

    struct ISendOptions {
        uint256 extraGasLimit;
        address zroPaymentAddress;
    }
    struct IApproval {
        bool allowFailure;
        address target;
        bool permitBorrow;
        address owner;
        address spender;
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }
    struct IWithdrawParams {
        bool withdraw;
        uint256 withdrawLzFeeAmount;
        bool withdrawOnOtherChain;
        uint16 withdrawLzChainId;
        bytes withdrawAdapterParams;
    }
    struct IBorrowParams {
        uint256 amount;
        uint256 borrowAmount;
        address marketHelper;
        address market;
    }

    // ******************//
    // *** MODIFIERS *** //
    // ***************** //
    /// @notice Require that the caller is on the host chain of the ERC20.
    modifier onlyHostChain() {
        require(block.chainid == hostChainID, "TOFT_host");
        _;
    }

    receive() external payable {}

    constructor(
        address _lzEndpoint,
        address _erc20,
        IYieldBoxBase _yieldBox,
        string memory _name,
        string memory _symbol,
        uint8 _decimal,
        uint256 _hostChainID
    )
        OFTV2(
            string(abi.encodePacked("TapiocaOFT-", _name)),
            string(abi.encodePacked("t", _symbol)),
            _decimal / 2,
            _lzEndpoint
        )
        ERC20Permit(string(abi.encodePacked("TapiocaOFT-", _name)))
    {
        erc20 = _erc20;
        _decimalCache = _decimal;
        hostChainID = _hostChainID;
        yieldBox = _yieldBox;
    }

    // ********************** //
    // *** VIEW FUNCTIONS *** //
    // ********************** //
    /// @notice decimal number of the ERC20
    function decimals() public view override returns (uint8) {
        if (_decimalCache == 0) return 18; //temporary fix for LZ _sharedDecimals check
        return _decimalCache;
    }

    // ************************ //
    // *** PUBLIC FUNCTIONS *** //
    // ************************ //
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
        uint256 share,
        uint256 assetId,
        uint16 lzDstChainId,
        ISendOptions calldata options
    ) external payable {
        require(amount > 0, "TOFT_0");
        bytes32 toAddress = bytes32(uint(uint160(_to)));
        _debitFrom(_from, lzEndpoint.getChainId(), toAddress, amount);

        bytes memory lzPayload = abi.encode(
            PT_YB_SEND_STRAT,
            bytes32(uint(uint160(_from))),
            toAddress,
            amount,
            share,
            assetId
        );

        bytes memory adapterParam = abi.encodePacked(
            uint16(1),
            options.extraGasLimit
        );
        _lzSend(
            lzDstChainId,
            lzPayload,
            payable(_from),
            options.zroPaymentAddress,
            adapterParam,
            msg.value
        );

        emit SendToChain(lzDstChainId, _from, toAddress, amount);
    }

    /// @notice sends TOFT to a specific chain and performs a borrow operation
    /// @param _from the sender address
    /// @param _to the receiver address
    /// @param lzDstChainId the destination LayerZero id
    /// @param airdropAdapterParams the LayerZero aidrop adapter params
    /// @param borrowParams the borrow operation data
    /// @param withdrawParams the withdraw operation data
    /// @param options the cross chain send operation data
    /// @param approvals the cross chain approval operation data
    function sendToYBAndBorrow(
        address _from,
        address _to,
        uint16 lzDstChainId,
        bytes calldata airdropAdapterParams,
        IBorrowParams calldata borrowParams,
        IWithdrawParams calldata withdrawParams,
        ISendOptions calldata options,
        IApproval[] calldata approvals
    ) external payable {
        bytes32 toAddress = bytes32(uint(uint160(_to)));
        _debitFrom(
            _from,
            lzEndpoint.getChainId(),
            toAddress,
            borrowParams.amount
        );

        bytes memory lzPayload = abi.encode(
            PT_YB_SEND_SGL_BORROW,
            _from,
            toAddress,
            borrowParams,
            withdrawParams,
            approvals
        );

        _lzSend(
            lzDstChainId,
            lzPayload,
            payable(_from),
            options.zroPaymentAddress,
            airdropAdapterParams,
            msg.value
        );

        emit SendToChain(lzDstChainId, _from, toAddress, borrowParams.amount);
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
        uint256 share,
        uint256 assetId,
        uint16 lzDstChainId,
        address zroPaymentAddress,
        bytes memory airdropAdapterParam
    ) external payable {
        require(amount > 0, "TOFT_0");

        bytes32 toAddress = bytes32(uint(uint160(msg.sender)));

        bytes memory lzPayload = abi.encode(
            PT_YB_RETRIEVE_STRAT,
            bytes32(uint(uint160(_from))),
            toAddress,
            amount,
            share,
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

    function sendForLeverage(
        uint256 amount,
        address leverageFor,
        IUSDOBase.ILeverageLZData calldata lzData,
        IUSDOBase.ILeverageSwapData calldata swapData,
        IUSDOBase.ILeverageExternalContractsData calldata externalData
    ) external payable {
        bytes32 senderBytes = bytes32(uint(uint160(msg.sender)));
        _debitFrom(msg.sender, lzEndpoint.getChainId(), senderBytes, amount);

        bytes memory lzPayload = abi.encode(
            PT_LEVERAGE_MARKET_DOWN,
            senderBytes,
            amount,
            swapData,
            externalData,
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

    // ************************* //
    // *** PRIVATE FUNCTIONS *** //
    // ************************* //

    function _isNative() internal view returns (bool) {
        return erc20 == address(0);
    }

    function _wrap(
        address _fromAddress,
        address _toAddress,
        uint256 _amount
    ) internal virtual {
        if (_fromAddress != msg.sender) {
            require(
                allowance(_fromAddress, msg.sender) >= _amount,
                "TOFT_allowed"
            );
        }
        IERC20(erc20).safeTransferFrom(_fromAddress, address(this), _amount);
        _mint(_toAddress, _amount);
    }

    function _wrapNative(address _toAddress) internal virtual {
        require(msg.value > 0, "TOFT_0");
        _mint(_toAddress, msg.value);
    }

    function _unwrap(address _toAddress, uint256 _amount) internal virtual {
        _burn(msg.sender, _amount);

        if (_isNative()) {
            _safeTransferETH(_toAddress, _amount);
        } else {
            IERC20(erc20).safeTransfer(_toAddress, _amount);
        }
    }

    function _strategyDeposit(
        uint16 _srcChainId,
        bytes memory _payload,
        IERC20 _erc20
    ) internal virtual {
        (, , bytes32 from, uint256 amount, uint256 share, uint256 assetId) = abi
            .decode(
                _payload,
                (uint16, bytes32, bytes32, uint256, uint256, uint256)
            );

        address onBehalfOf = address(uint160(uint(from)));

        _creditTo(_srcChainId, address(this), amount);
        _depositToYieldbox(
            assetId,
            amount,
            share,
            _erc20,
            address(this),
            onBehalfOf
        );

        emit ReceiveFromChain(_srcChainId, onBehalfOf, amount);
    }

    function _strategyWithdraw(
        uint16 _srcChainId,
        bytes memory _payload
    ) internal virtual {
        (
            ,
            bytes32 from,
            ,
            uint256 _amount,
            uint256 _share,
            uint256 _assetId,
            address _zroPaymentAddress
        ) = abi.decode(
                _payload,
                (uint16, bytes32, bytes32, uint256, uint256, uint256, address)
            );

        address _from = address(uint160(uint(from)));
        _retrieveFromYieldBox(_assetId, _amount, _share, _from, address(this));

        _debitFrom(
            address(this),
            lzEndpoint.getChainId(),
            bytes32(uint(uint160(address(this)))),
            _amount
        );

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
            bytes32(uint(uint160(address(this)))),
            _amount
        );

        emit ReceiveFromChain(_srcChainId, _from, _amount);
    }

    /// @notice Deposit to this address, then use MarketHelper to deposit and add collateral, borrow and withdrawTo
    /// @dev Payload format: (uint16 packetType, bytes32 fromAddressBytes, bytes32 nonces, uint256 amount, uint256 borrowAmount, address MarketHelper, address Market)
    /// @param _srcChainId The chain id of the source chain
    /// @param _payload The payload of the packet
    function _borrow(
        uint16 _srcChainId,
        bytes memory _payload
    ) internal virtual {
        (
            ,
            address _from, //from
            ,
            IBorrowParams memory borrowParams,
            IWithdrawParams memory withdrawParams,
            IApproval[] memory approvals
        ) = abi.decode(
                _payload,
                (
                    uint16,
                    address,
                    bytes32,
                    IBorrowParams,
                    IWithdrawParams,
                    IApproval[]
                )
            );

        if (approvals.length > 0) {
            _callApproval(approvals);
        }
        _creditTo(_srcChainId, address(this), borrowParams.amount);

        // Use market helper to deposit, add collateral to market and withdrawTo
        bytes memory withdrawData = abi.encode(
            withdrawParams.withdrawOnOtherChain,
            withdrawParams.withdrawLzChainId,
            _from,
            withdrawParams.withdrawAdapterParams
        );
        approve(address(borrowParams.marketHelper), borrowParams.amount);
        IMagnetar(borrowParams.marketHelper).depositAddCollateralAndBorrow{
            value: msg.value
        }(
            borrowParams.market,
            _from,
            borrowParams.amount,
            borrowParams.borrowAmount,
            true,
            true,
            withdrawParams.withdraw,
            withdrawData
        );
    }

    function _leverageDown(
        uint16 _srcChainId,
        bytes memory _payload
    ) internal virtual {
        (
            ,
            ,
            uint256 amount,
            IUSDOBase.ILeverageSwapData memory swapData,
            IUSDOBase.ILeverageExternalContractsData memory externalData,
            address leverageFor
        ) = abi.decode(
                _payload,
                (
                    uint16,
                    bytes32,
                    uint256,
                    IUSDOBase.ILeverageSwapData,
                    IUSDOBase.ILeverageExternalContractsData,
                    address
                )
            );

        _creditTo(_srcChainId, address(this), amount);

        //unwrap
        _unwrap(address(this), amount);

        //swap to USDO
        _approve(erc20, externalData.swapper, amount);
        ISwapper.SwapData memory _swapperData = ISwapper(externalData.swapper)
            .buildSwapData(erc20, swapData.tokenOut, amount, 0, false, false);
        (uint256 amountOut, ) = ISwapper(externalData.swapper).swap(
            _swapperData,
            swapData.amountOutMin,
            address(this),
            swapData.data
        );

        //repay
        _approve(swapData.tokenOut, externalData.magnetar, amountOut);
        IMagnetar(externalData.magnetar).depositAndRepay(
            externalData.srcMarket,
            leverageFor,
            amountOut,
            amountOut,
            true,
            true
        );
    }

    function _callApproval(IApproval[] memory approvals) private {
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

    /// @notice Receive an inter-chain transaction to execute a deposit inside YieldBox.
    function _depositToYieldbox(
        uint256 _assetId,
        uint256 _amount,
        uint256 _share,
        IERC20 _erc20,
        address _from,
        address _to
    ) private {
        _amount = _share > 0
            ? yieldBox.toAmount(_assetId, _share, false)
            : _amount;
        _erc20.approve(address(yieldBox), _amount);
        yieldBox.depositAsset(_assetId, _from, _to, _amount, _share);
    }

    /// @notice Receive an inter-chain transaction to execute a deposit inside YieldBox.
    function _retrieveFromYieldBox(
        uint256 _assetId,
        uint256 _amount,
        uint256 _share,
        address _from,
        address _to
    ) private {
        yieldBox.withdraw(_assetId, _from, _to, _amount, _share);
    }

    function _safeTransferETH(address to, uint256 amount) internal {
        (bool sent, ) = to.call{value: amount}("");
        require(sent, "TOFT_failed");
    }

    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) internal virtual override {
        uint256 packetType = _payload.toUint256(0);

        if (packetType == PT_YB_SEND_STRAT) {
            _strategyDeposit(_srcChainId, _payload, IERC20(address(this)));
        } else if (packetType == PT_YB_RETRIEVE_STRAT) {
            _strategyWithdraw(_srcChainId, _payload);
        } else if (packetType == PT_YB_SEND_SGL_BORROW) {
            _borrow(_srcChainId, _payload);
        } else if (packetType == PT_LEVERAGE_MARKET_DOWN) {
            _leverageDown(_srcChainId, _payload);
        } else {
            packetType = _payload.toUint8(0);
            if (packetType == PT_SEND) {
                _sendAck(_srcChainId, _srcAddress, _nonce, _payload);
            } else if (packetType == PT_SEND_AND_CALL) {
                _sendAndCallAck(_srcChainId, _srcAddress, _nonce, _payload);
            } else {
                revert("OFTCoreV2: unknown packet type");
            }
        }
    }
}
