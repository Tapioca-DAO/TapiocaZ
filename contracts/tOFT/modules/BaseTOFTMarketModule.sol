// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

//LZ
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol";

//TAPIOCA
import {IUSDOBase} from "tapioca-periph/contracts/interfaces/IUSDO.sol";
import "tapioca-periph/contracts/interfaces/ISwapper.sol";
import "tapioca-periph/contracts/interfaces/ITapiocaOFT.sol";
import "tapioca-periph/contracts/interfaces/IMagnetar.sol";
import "tapioca-periph/contracts/interfaces/IMarket.sol";
import "tapioca-periph/contracts/interfaces/IPermitBorrow.sol";
import "tapioca-periph/contracts/interfaces/IPermitAll.sol";

import "./TOFTCommon.sol";

contract BaseTOFTMarketModule is TOFTCommon {
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

    // function initMultiSell(
    //     address from,
    //     uint256 amount,
    //     IUSDOBase.ILeverageSwapData calldata swapData,
    //     IUSDOBase.ILeverageLZData calldata lzData,
    //     IUSDOBase.ILeverageExternalContractsData calldata externalData,
    //     bytes calldata airdropAdapterParams,
    //     ICommonData.IApproval[] calldata approvals
    // ) external payable {
    //     //allowance is also checked on market
    //     if (from != msg.sender) {
    //         require(allowance(from, msg.sender) >= amount, "TOFT_UNAUTHORIZED");
    //         _spendAllowance(from, msg.sender, amount);
    //     }

    //     _assureMaxSlippage(amount, swapData.amountOutMin);
    //     bytes32 senderBytes = LzLib.addressToBytes32(from);

    //     (amount, ) = _removeDust(amount);
    //     bytes memory lzPayload = abi.encode(
    //         PT_MARKET_MULTIHOP_SELL,
    //         senderBytes,
    //         from,
    //         _ld2sd(amount),
    //         swapData,
    //         lzData,
    //         externalData,
    //         airdropAdapterParams,
    //         approvals
    //     );

    //     _checkGasLimit(
    //         lzData.lzSrcChainId,
    //         PT_MARKET_MULTIHOP_SELL,
    //         airdropAdapterParams,
    //         NO_EXTRA_GAS
    //     );
    //     _lzSend(
    //         lzData.lzSrcChainId,
    //         lzPayload,
    //         payable(lzData.refundAddress),
    //         lzData.zroPaymentAddress,
    //         airdropAdapterParams,
    //         msg.value
    //     );
    //     emit SendToChain(lzData.lzSrcChainId, msg.sender, senderBytes, 0);
    // }

    function removeCollateral(
        address from,
        address to,
        uint16 lzDstChainId,
        address zroPaymentAddress,
        ICommonData.IWithdrawParams calldata withdrawParams,
        ITapiocaOFT.IRemoveParams memory removeParams,
        ICommonData.IApproval[] calldata approvals,
        bytes calldata adapterParams
    ) external payable {
        //allowance is also checked on market
        if (from != msg.sender) {
            require(
                allowance(from, msg.sender) >= removeParams.amount,
                "TOFT_UNAUTHORIZED"
            );
            _spendAllowance(from, msg.sender, removeParams.amount);
        }

        bytes32 toAddress = LzLib.addressToBytes32(to);
        (removeParams.amount, ) = _removeDust(removeParams.amount);

        bytes memory lzPayload = abi.encode(
            PT_MARKET_REMOVE_COLLATERAL,
            from,
            toAddress,
            _ld2sd(removeParams.amount),
            removeParams,
            withdrawParams,
            approvals
        );

        _checkGasLimit(
            lzDstChainId,
            PT_MARKET_REMOVE_COLLATERAL,
            adapterParams,
            NO_EXTRA_GAS
        );

        //fail fast
        require(
            cluster.isWhitelisted(lzDstChainId, removeParams.market),
            "TOFT_INVALID"
        );
        if (withdrawParams.withdraw) {
            require(
                cluster.isWhitelisted(lzDstChainId, removeParams.marketHelper),
                "TOFT_INVALID"
            );
        }

        _lzSend(
            lzDstChainId,
            lzPayload,
            payable(from),
            zroPaymentAddress,
            adapterParams,
            msg.value
        );

        emit SendToChain(lzDstChainId, from, toAddress, 0);
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
        ITapiocaOFT.IBorrowParams calldata borrowParams,
        ICommonData.IWithdrawParams calldata withdrawParams,
        ICommonData.ISendOptions calldata options,
        ICommonData.IApproval[] calldata approvals
    ) external payable {
        if (_from != msg.sender) {
            require(
                allowance(_from, msg.sender) >= borrowParams.amount,
                "TOFT_UNAUTHORIZED"
            );
            _spendAllowance(_from, msg.sender, borrowParams.amount);
        }

        bytes32 toAddress = LzLib.addressToBytes32(_to);

        (uint256 amount, ) = _removeDust(borrowParams.amount);
        _debitFrom(_from, lzEndpoint.getChainId(), toAddress, amount);
        (, , uint256 airdropAmount, ) = LzLib.decodeAdapterParams(
            airdropAdapterParams
        );
        bytes memory lzPayload = abi.encode(
            PT_YB_SEND_SGL_BORROW,
            _from,
            toAddress,
            _ld2sd(amount),
            borrowParams,
            withdrawParams,
            approvals,
            airdropAmount
        );

        _checkGasLimit(
            lzDstChainId,
            PT_YB_SEND_SGL_BORROW,
            airdropAdapterParams,
            NO_EXTRA_GAS
        );
        _lzSend(
            lzDstChainId,
            lzPayload,
            payable(_from),
            options.zroPaymentAddress,
            airdropAdapterParams,
            msg.value
        );

        emit SendToChain(lzDstChainId, _from, toAddress, amount);
    }

    function borrow(
        address module,
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) public payable {
        require(msg.sender == address(this), "TOFT_CALLER");
        require(validModules[module], "TOFT_MODULE");
        (
            ,
            address _from, //from
            bytes32 _to,
            uint64 amountSD,
            ITapiocaOFT.IBorrowParams memory borrowParams,
            ICommonData.IWithdrawParams memory withdrawParams,
            ICommonData.IApproval[] memory approvals,
            uint256 airdropAmount
        ) = abi.decode(
                _payload,
                (
                    uint16,
                    address,
                    bytes32,
                    uint64,
                    ITapiocaOFT.IBorrowParams,
                    ICommonData.IWithdrawParams,
                    ICommonData.IApproval[],
                    uint256
                )
            );

        borrowParams.amount = _sd2ld(amountSD);

        uint256 balanceBefore = balanceOf(address(this));
        bool credited = creditedPackets[_srcChainId][_srcAddress][_nonce];
        if (!credited) {
            _creditTo(_srcChainId, address(this), borrowParams.amount);
            creditedPackets[_srcChainId][_srcAddress][_nonce] = true;
        }
        uint256 balanceAfter = balanceOf(address(this));

        (bool success, bytes memory reason) = module.delegatecall(
            abi.encodeWithSelector(
                this.borrowInternal.selector,
                _to,
                borrowParams,
                withdrawParams,
                approvals,
                airdropAmount
            )
        );

        if (!success) {
            if (balanceAfter - balanceBefore >= borrowParams.amount) {
                IERC20(address(this)).safeTransfer(_from, borrowParams.amount);
            }
            _storeFailedMessage(
                _srcChainId,
                _srcAddress,
                _nonce,
                _payload,
                reason
            );
        }

        emit ReceiveFromChain(_srcChainId, _from, borrowParams.amount);
    }

    function borrowInternal(
        bytes32 _to,
        ITapiocaOFT.IBorrowParams memory borrowParams,
        ICommonData.IWithdrawParams memory withdrawParams,
        ICommonData.IApproval[] memory approvals,
        uint256 airdropAmount
    ) public payable {
        if (approvals.length > 0) {
            _callApproval(approvals, PT_YB_SEND_SGL_BORROW);
        }

        // Use market helper to deposit, add collateral to market and withdrawTo
        approve(address(borrowParams.marketHelper), borrowParams.amount);

        uint256 gas = withdrawParams.withdraw
            ? (msg.value > 0 ? msg.value : airdropAmount)
            : 0;
        IMagnetar(borrowParams.marketHelper)
            .depositAddCollateralAndBorrowFromMarket{value: gas}(
            borrowParams.market,
            LzLib.bytes32ToAddress(_to),
            borrowParams.amount,
            borrowParams.borrowAmount,
            true,
            true,
            withdrawParams
        );
    }

    function remove(bytes memory _payload) public {
        require(msg.sender == address(this), "TOFT_CALLER");
        (
            ,
            address from,
            bytes32 toBytes,
            uint64 removeCollateralAmount,
            ITapiocaOFT.IRemoveParams memory removeParams,
            ICommonData.IWithdrawParams memory withdrawParams,
            ICommonData.IApproval[] memory approvals
        ) = abi.decode(
                _payload,
                (
                    uint16,
                    address,
                    bytes32,
                    uint64,
                    ITapiocaOFT.IRemoveParams,
                    ICommonData.IWithdrawParams,
                    ICommonData.IApproval[]
                )
            );

        address to = LzLib.bytes32ToAddress(toBytes);
        if (approvals.length > 0) {
            _callApproval(approvals, PT_MARKET_REMOVE_COLLATERAL);
        }

        removeParams.amount = _sd2ld(removeCollateralAmount);

        address ybAddress = IMarket(removeParams.market).yieldBox();
        uint256 assetId = IMarket(removeParams.market).collateralId();

        uint256 share = IYieldBoxBase(ybAddress).toShare(
            assetId,
            removeParams.amount,
            false
        );

        //market whitelist status
        require(cluster.isWhitelisted(0, removeParams.market), "TOFT_INVALID");
        approve(removeParams.market, share);
        IMarket(removeParams.market).removeCollateral(from, to, share);
        if (withdrawParams.withdraw) {
            require(
                cluster.isWhitelisted(0, removeParams.marketHelper),
                "TOFT_INVALID"
            );
            IMagnetar(removeParams.marketHelper).withdrawToChain{
                value: withdrawParams.withdrawLzFeeAmount
            }(
                ybAddress,
                to,
                assetId,
                withdrawParams.withdrawLzChainId,
                LzLib.addressToBytes32(to),
                removeParams.amount,
                withdrawParams.withdrawAdapterParams,
                payable(to),
                withdrawParams.withdrawLzFeeAmount
            );
        }
    }
}
