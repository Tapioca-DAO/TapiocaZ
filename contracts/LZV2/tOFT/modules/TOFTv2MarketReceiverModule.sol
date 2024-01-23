// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol"; //todo: it can be removed after Magnetar V2 migration

// External
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BytesLib} from "solidity-bytes-utils/contracts/BytesLib.sol";

// Tapioca
import {TOFTInitStruct, MarketBorrowMsg, MarketRemoveCollateralMsg, MarketLeverageDownMsg} from "contracts/ITOFTv2.sol";
import {IYieldBoxBase} from "tapioca-periph/contracts/interfaces/IYieldBoxBase.sol";
import {ITapiocaOFT} from "tapioca-periph/contracts/interfaces/ITapiocaOFT.sol";
import {ICommonData} from "tapioca-periph/contracts/interfaces/ICommonData.sol";
import {IMagnetar} from "tapioca-periph/contracts/interfaces/IMagnetar.sol";
import {ISwapper} from "tapioca-periph/contracts/interfaces/ISwapper.sol";
import {IUSDOBase} from "tapioca-periph/contracts/interfaces/IUSDO.sol";
import {IMarket} from "tapioca-periph/contracts/interfaces/IMarket.sol";
import {TOFTMsgCoder} from "contracts/libraries/TOFTMsgCoder.sol";
import {BaseTOFTv2} from "contracts/BaseTOFTv2.sol";

/*
__/\\\\\\\\\\\\\\\_____/\\\\\\\\\_____/\\\\\\\\\\\\\____/\\\\\\\\\\\_______/\\\\\_____________/\\\\\\\\\_____/\\\\\\\\\____        
 _\///////\\\/////____/\\\\\\\\\\\\\__\/\\\/////////\\\_\/////\\\///______/\\\///\\\________/\\\////////____/\\\\\\\\\\\\\__       
  _______\/\\\________/\\\/////////\\\_\/\\\_______\/\\\_____\/\\\_______/\\\/__\///\\\____/\\\/____________/\\\/////////\\\_      
   _______\/\\\_______\/\\\_______\/\\\_\/\\\\\\\\\\\\\/______\/\\\______/\\\______\//\\\__/\\\_____________\/\\\_______\/\\\_     
    _______\/\\\_______\/\\\\\\\\\\\\\\\_\/\\\/////////________\/\\\_____\/\\\_______\/\\\_\/\\\_____________\/\\\\\\\\\\\\\\\_    
     _______\/\\\_______\/\\\/////////\\\_\/\\\_________________\/\\\_____\//\\\______/\\\__\//\\\____________\/\\\/////////\\\_   
      _______\/\\\_______\/\\\_______\/\\\_\/\\\_________________\/\\\______\///\\\__/\\\_____\///\\\__________\/\\\_______\/\\\_  
       _______\/\\\_______\/\\\_______\/\\\_\/\\\______________/\\\\\\\\\\\____\///\\\\\/________\////\\\\\\\\\_\/\\\_______\/\\\_ 
        _______\///________\///________\///__\///______________\///////////_______\/////_____________\/////////__\///________\///__

*/

//TODO: perform ld2sd and sd2ld on uint256

/**
 * @title TOFTv2MarketReceiverModule
 * @author TapiocaDAO
 * @notice TOFTv2 Market module
 */
contract TOFTv2MarketReceiverModule is BaseTOFTv2 {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    error TOFTv2MarketReceiverModule_NotAuthorized(address invalidAddress);

    event BorrowReceived(
        address indexed user,
        address indexed market,
        uint256 indexed amount,
        bool deposit,
        bool withdraw
    );

    event RemoveCollateralReceived(
        address indexed user,
        address indexed market,
        uint256 indexed amount,
        bool withdraw
    );

    event LeverageDownReceived(
        address indexed user,
        address indexed market,
        uint256 indexed amount
    );

    constructor(TOFTInitStruct memory _data) BaseTOFTv2(_data) {}

    //TODO: debit from 'from' or remove 'from' and use sender
    /**
     * @notice Calls depositAddCollateralAndBorrowFromMarket on Magnetar
     * @param _data The call data containing info about the operation.
     *      - from::address: Address to debit tokens from.
     *      - to::address: Address to execute operations on.
     *      - borrowParams::struct: Borrow operation related params.
     *      - withdrawParams::struct: Withdraw related params.
     */
    function marketBorrowReceiver(bytes memory _data) public payable {
        _sanitizeSender();

        // @dev decode received message
        MarketBorrowMsg memory marketBorrowMsg_ = TOFTMsgCoder
            .decodeMarketBorrowMsg(_data);

        // @dev sanitize 'borrowParams.marketHelper' and 'borrowParams.market'
        _checkWhitelistStatus(marketBorrowMsg_.borrowParams.marketHelper);
        _checkWhitelistStatus(marketBorrowMsg_.borrowParams.market);

        // @dev use market helper to deposit, add collateral to market and withdrawTo
        // @dev 'borrowParams.marketHelper' is MagnetarV2 contract
        approve(
            address(marketBorrowMsg_.borrowParams.marketHelper),
            marketBorrowMsg_.borrowParams.amount
        );
        IMagnetar(marketBorrowMsg_.borrowParams.marketHelper)
            .depositAddCollateralAndBorrowFromMarket{value: msg.value}(
            marketBorrowMsg_.borrowParams.market,
            marketBorrowMsg_.to,
            marketBorrowMsg_.borrowParams.amount,
            marketBorrowMsg_.borrowParams.borrowAmount,
            false, //extract from user; he needs to approve magnetar
            marketBorrowMsg_.borrowParams.deposit,
            marketBorrowMsg_.withdrawParams
        );

        emit BorrowReceived(
            marketBorrowMsg_.to,
            marketBorrowMsg_.borrowParams.market,
            marketBorrowMsg_.borrowParams.amount,
            marketBorrowMsg_.borrowParams.deposit,
            marketBorrowMsg_.withdrawParams.withdraw
        );
    }

    /**
     * @notice Performs market.removeCollateral()
     * @param _data The call data containing info about the operation.
     *      - from::address: Address to debit tokens from.
     *      - to::address: Address to execute operations on.
     *      - removeParams::struct: Remove collateral operation related params.
     *      - withdrawParams::struct: Withdraw related params.
     */
    function marketRemoveCollateralReceiver(bytes memory _data) public payable {
        _sanitizeSender();

        // @dev decode received message
        MarketRemoveCollateralMsg memory msg_ = TOFTMsgCoder
            .decodeMarketRemoveCollateralMsg(_data);

        _checkWhitelistStatus(msg_.removeParams.market);

        address ybAddress = IMarket(msg_.removeParams.market).yieldBox();
        uint256 assetId = IMarket(msg_.removeParams.market).collateralId();

        {
            uint256 share = IYieldBoxBase(ybAddress).toShare(
                assetId,
                msg_.removeParams.amount,
                false
            );
            approve(msg_.removeParams.market, share);
            IMarket(msg_.removeParams.market).removeCollateral(
                msg_.from,
                msg_.to,
                share
            );
        }

        {
            if (msg_.withdrawParams.withdraw) {
                if (!cluster.isWhitelisted(0, msg_.removeParams.marketHelper))
                    revert TOFTv2MarketReceiverModule_NotAuthorized(
                        msg_.removeParams.marketHelper
                    );
                IMagnetar(msg_.removeParams.marketHelper).withdrawToChain{
                    value: msg_.withdrawParams.withdrawLzFeeAmount
                }(
                    ybAddress,
                    msg_.to,
                    assetId,
                    msg_.withdrawParams.withdrawLzChainId,
                    LzLib.addressToBytes32(msg_.to),
                    msg_.removeParams.amount,
                    msg_.withdrawParams.withdrawAdapterParams,
                    payable(msg_.to),
                    msg_.withdrawParams.withdrawLzFeeAmount,
                    msg_.withdrawParams.unwrap,
                    msg_.withdrawParams.zroPaymentAddress
                );
            }
        }

        emit RemoveCollateralReceived(
            msg_.to,
            msg_.removeParams.market,
            msg_.removeParams.amount,
            msg_.withdrawParams.withdraw
        );
    }

    /**
     * @notice Performs market.leverageDown()
     * @param _data The call data containing info about the operation.
     *      - leverageFor::address: Address to leverage for.
     *      - amount::uint256: Address to debit tokens from.
     *      - swapData::struct: Swap operation related params
     *      - externalData::struct: Struct containing addresses used by this operation.
     *      - lzSendParam::struct: LZ v2 send back to source params
     *      - composeMsg::bytes: lzCompose message to be executed back on source
     */
    function marketLeverageDownReceiver(bytes memory _data) public payable {
        _sanitizeSender();

        // @dev decode received message
        MarketLeverageDownMsg memory msg_ = TOFTMsgCoder
            .decodeMarketLeverageDownMsg(_data);

        _checkWhitelistStatus(msg_.externalData.srcMarket);
        _checkWhitelistStatus(msg_.externalData.magnetar);
        _checkWhitelistStatus(msg_.externalData.swapper);
        _checkWhitelistStatus(msg_.externalData.tOft);
        _checkWhitelistStatus(
            LzLib.bytes32ToAddress(msg_.lzSendParams.sendParam.to)
        );

        uint256 amountOut;
        {
            ISwapper.SwapData memory _swapperData = ISwapper(
                msg_.externalData.swapper
            ).buildSwapData(erc20, msg_.swapData.tokenOut, msg_.amount, 0);
            (amountOut, ) = ISwapper(msg_.externalData.swapper).swap{
                value: erc20 == address(0) ? msg_.amount : 0
            }(
                _swapperData,
                msg_.swapData.amountOutMin,
                address(this),
                msg_.swapData.data
            );
        }

        emit LeverageDownReceived(
            msg_.leverageFor,
            msg_.externalData.srcMarket,
            msg_.amount
        );

        //repay for leverage down
        // @dev TODO: refactor after USDO is migrated to V2
        // @dev it won't work until USDO is migrated

        // ICommonData.IApproval[] memory approvals;
        // IUSDOBase(swapData.tokenOut).sendAndLendOrRepay{value: airdropAmount}(
        //     address(this),
        //     msg_.leverageFor,
        //     lzData.lzSrcChainId,
        //     lzData.zroPaymentAddress,
        //     IUSDOBase.ILendOrRepayParams({
        //         repay: true,
        //         depositAmount: amountOut,
        //         repayAmount: 0, //it will be computed automatically at the destination IUSDO call
        //         marketHelper: externalData.magnetar,
        //         market: externalData.srcMarket,
        //         removeCollateral: false,
        //         removeCollateralAmount: 0,
        //         lockData: ITapiocaOptionLiquidityProvision.IOptionsLockData({
        //             lock: false,
        //             target: address(0),
        //             lockDuration: 0,
        //             amount: 0,
        //             fraction: 0
        //         }),
        //         participateData: ITapiocaOptionsBroker.IOptionsParticipateData({
        //             participate: false,
        //             target: address(0),
        //             tOLPTokenId: 0
        //         })
        //     }),
        //     approvals,
        //     approvals,
        //     ICommonData.IWithdrawParams({
        //         withdraw: false,
        //         withdrawLzFeeAmount: 0,
        //         withdrawOnOtherChain: false,
        //         withdrawLzChainId: 0,
        //         withdrawAdapterParams: "0x",
        //         unwrap: false,
        //         refundAddress: payable(lzData.refundAddress),
        //         zroPaymentAddress: lzData.zroPaymentAddress
        //     }),
        //     LzLib.buildDefaultAdapterParams(lzData.srcExtraGasLimit)
        // );
    }

    function _sanitizeSender() private view {
        if (msg.sender != address(endpoint))
            revert TOFTv2MarketReceiverModule_NotAuthorized(msg.sender);
    }

    function _checkWhitelistStatus(address _addr) private view {
        if (_addr != address(0)) {
            if (!cluster.isWhitelisted(0, _addr))
                revert TOFTv2MarketReceiverModule_NotAuthorized(_addr);
        }
    }
}
