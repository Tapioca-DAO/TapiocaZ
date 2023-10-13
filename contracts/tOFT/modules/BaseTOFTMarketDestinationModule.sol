// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

//LZ
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol";

//TAPIOCA
import {IUSDOBase} from "tapioca-periph/contracts/interfaces/IUSDO.sol";
import "tapioca-periph/contracts/interfaces/ITapiocaOFT.sol";
import "tapioca-periph/contracts/interfaces/IMagnetar.sol";
import "tapioca-periph/contracts/interfaces/IMarket.sol";

import "./TOFTCommon.sol";

contract BaseTOFTMarketDestinationModule is TOFTCommon {
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

    function borrow(
        address module,
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) public payable {
        require(
            msg.sender == address(this) &&
                _moduleAddresses[Module.MarketDestination] == module,
            "TOFT_CALLER"
        );
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
                module,
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
        address module,
        bytes32 _to,
        ITapiocaOFT.IBorrowParams memory borrowParams,
        ICommonData.IWithdrawParams memory withdrawParams,
        ICommonData.IApproval[] memory approvals,
        uint256 airdropAmount
    ) public payable {
        require(
            msg.sender == address(this) &&
                _moduleAddresses[Module.MarketDestination] == module,
            "TOFT_CALLER"
        );
        if (approvals.length > 0) {
            _callApproval(approvals, PT_YB_SEND_SGL_BORROW);
        }

        // Use market helper to deposit, add collateral to market and withdrawTo
        approve(address(borrowParams.marketHelper), borrowParams.amount);

        IMagnetar(borrowParams.marketHelper)
            .depositAddCollateralAndBorrowFromMarket{value: airdropAmount}(
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
            ICommonData.IApproval[] memory approvals,
            uint256 airdropAmount
        ) = abi.decode(
                _payload,
                (
                    uint16,
                    address,
                    bytes32,
                    uint64,
                    ITapiocaOFT.IRemoveParams,
                    ICommonData.IWithdrawParams,
                    ICommonData.IApproval[],
                    uint256
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
        if (removeParams.market != address(0)) {
            require(
                cluster.isWhitelisted(0, removeParams.market),
                "TOFT_INVALID"
            );
        }
        approve(removeParams.market, share);
        IMarket(removeParams.market).removeCollateral(from, to, share);
        if (withdrawParams.withdraw) {
            require(
                airdropAmount >= withdrawParams.withdrawLzFeeAmount,
                "TOFT_GAS"
            );
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
