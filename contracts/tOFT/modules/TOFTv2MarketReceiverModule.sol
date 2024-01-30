// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BytesLib} from "solidity-bytes-utils/contracts/BytesLib.sol";

// LZ
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol"; //todo: it can be removed after Magnetar V2 migration

// Tapioca
import {
    TOFTInitStruct, MarketBorrowMsg, MarketRemoveCollateralMsg, MarketLeverageDownMsg
} from "contracts/ITOFTv2.sol";
import {ITapiocaOFT} from "tapioca-periph/interfaces/tap-token/ITapiocaOFT.sol";
import {ICommonData} from "tapioca-periph/interfaces/common/ICommonData.sol";
import {IYieldBox} from "tapioca-periph/interfaces/yieldbox/IYieldBox.sol";
import {IMagnetar} from "tapioca-periph/interfaces/periph/IMagnetar.sol";
import {ISwapper} from "tapioca-periph/interfaces/periph/ISwapper.sol";
import {IUSDOBase} from "tapioca-periph/interfaces/bar/IUSDO.sol";
import {IMarket} from "tapioca-periph/interfaces/bar/IMarket.sol";
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
        address indexed user, address indexed market, uint256 indexed amount, bool deposit, bool withdraw
    );

    event RemoveCollateralReceived(address indexed user, address indexed market, uint256 indexed amount, bool withdraw);

    event LeverageDownReceived(address indexed user, address indexed market, uint256 indexed amount);

    constructor(TOFTInitStruct memory _data) BaseTOFTv2(_data) {}

    /**
     * @notice Calls depositAddCollateralAndBorrowFromMarket on Magnetar
     * @param _data The call data containing info about the operation.
     *      - from::address: Address to debit tokens from.
     *      - to::address: Address to execute operations on.
     *      - borrowParams::struct: Borrow operation related params.
     *      - withdrawParams::struct: Withdraw related params.
     */
    function marketBorrowReceiver(bytes memory _data) public payable {
        /// @dev decode received message
        MarketBorrowMsg memory msg_ = TOFTMsgCoder.decodeMarketBorrowMsg(_data);

        /// @dev sanitize 'borrowParams.marketHelper' and 'borrowParams.market'
        _checkWhitelistStatus(msg_.borrowParams.marketHelper);
        _checkWhitelistStatus(msg_.borrowParams.market);

        msg_.borrowParams.amount = _toLD(uint64(msg_.borrowParams.amount));
        msg_.borrowParams.borrowAmount = _toLD(uint64(msg_.borrowParams.borrowAmount));

        /// @dev use market helper to deposit, add collateral to market and withdrawTo
        /// @dev 'borrowParams.marketHelper' is MagnetarV2 contract
        approve(address(msg_.borrowParams.marketHelper), msg_.borrowParams.amount);
        IMagnetar(payable(msg_.borrowParams.marketHelper)).depositAddCollateralAndBorrowFromMarket{value: msg.value}(
            IMagnetar.DepositAddCollateralAndBorrowFromMarketData(
                msg_.borrowParams.market,
                msg_.user,
                msg_.borrowParams.amount,
                msg_.borrowParams.borrowAmount,
                false,
                msg_.borrowParams.deposit,
                msg_.withdrawParams,
                msg.value
            )
        );
        emit BorrowReceived(
            msg_.user,
            msg_.borrowParams.market,
            msg_.borrowParams.amount,
            msg_.borrowParams.deposit,
            msg_.withdrawParams.withdraw
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
        /// @dev decode received message
        MarketRemoveCollateralMsg memory msg_ = TOFTMsgCoder.decodeMarketRemoveCollateralMsg(_data);

        _checkWhitelistStatus(msg_.removeParams.market);

        address ybAddress = IMarket(msg_.removeParams.market).yieldBox();
        uint256 assetId = IMarket(msg_.removeParams.market).collateralId();

        msg_.removeParams.amount = _toLD(uint64(msg_.removeParams.amount));

        {
            uint256 share = IYieldBox(ybAddress).toShare(assetId, msg_.removeParams.amount, false);
            approve(msg_.removeParams.market, share);
            IMarket(msg_.removeParams.market).removeCollateral(msg_.user, msg_.user, share);
        }

        {
            //TODO: refactor after periph is updated
            if (msg_.withdrawParams.withdraw) {
                if (!cluster.isWhitelisted(0, msg_.removeParams.marketHelper)) {
                    revert TOFTv2MarketReceiverModule_NotAuthorized(msg_.removeParams.marketHelper);
                }
                IMagnetar(payable(msg_.removeParams.marketHelper)).withdrawToChain{value: msg.value}(
                    IMagnetar.WithdrawToChainData(
                        ybAddress,
                        msg_.user,
                        assetId,
                        msg_.withdrawParams.withdrawLzChainId,
                        LzLib.addressToBytes32(msg_.user),
                        msg_.removeParams.amount,
                        msg_.withdrawParams.withdrawAdapterParams,
                        payable(msg_.user),
                        msg.value,
                        msg_.withdrawParams.unwrap,
                        msg_.withdrawParams.zroPaymentAddress
                    )
                );
            }
        }

        emit RemoveCollateralReceived(
            msg_.user, msg_.removeParams.market, msg_.removeParams.amount, msg_.withdrawParams.withdraw
        );
    }

    //TODO: test after USDO v2 migration
    /**
     * @notice Performs market.leverageDown()
     * @param _data The call data containing info about the operation.
     *      - user::address: Address to leverage for.
     *      - amount::uint256: Address to debit tokens from.
     *      - swapData::struct: Swap operation related params
     *      - externalData::struct: Struct containing addresses used by this operation.
     *      - lzSendParam::struct: LZ v2 send back to source params
     *      - composeMsg::bytes: lzCompose message to be executed back on source
     */
    function marketLeverageDownReceiver(bytes memory _data) public payable {
        /// @dev decode received message
        MarketLeverageDownMsg memory msg_ = TOFTMsgCoder.decodeMarketLeverageDownMsg(_data);

        _checkWhitelistStatus(msg_.externalData.srcMarket);
        _checkWhitelistStatus(msg_.externalData.magnetar);
        _checkWhitelistStatus(msg_.externalData.swapper);
        _checkWhitelistStatus(msg_.externalData.tOft);
        _checkWhitelistStatus(msg_.swapData.tokenOut);
        _checkWhitelistStatus(LzLib.bytes32ToAddress(msg_.lzSendParams.sendParam.to));

        msg_.amount = _toLD(uint64(msg_.amount));
        msg_.swapData.amountOutMin = _toLD(uint64(msg_.swapData.amountOutMin));

        uint256 amountOut;
        {
            ISwapper.SwapData memory _swapperData =
                ISwapper(msg_.externalData.swapper).buildSwapData(erc20, msg_.swapData.tokenOut, msg_.amount, 0);
            (amountOut,) = ISwapper(msg_.externalData.swapper).swap{value: erc20 == address(0) ? msg_.amount : 0}(
                _swapperData, msg_.swapData.amountOutMin, address(this), msg_.swapData.data
            );
        }

        emit LeverageDownReceived(msg_.user, msg_.externalData.srcMarket, msg_.amount);

        //repay for leverage down
        /// @dev TODO: refactor after USDO is migrated to V2
        /// @dev it won't work until USDO is migrated

        // ICommonData.IApproval[] memory approvals;
        // IUSDOBase(swapData.tokenOut).sendAndLendOrRepay{value: airdropAmount}(
        //     address(this),
        //     msg_.user,
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
        //         participateData: ITapiocaOptionBroker.IOptionsParticipateData({
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

    function _checkWhitelistStatus(address _addr) private view {
        if (_addr != address(0)) {
            if (!cluster.isWhitelisted(0, _addr)) {
                revert TOFTv2MarketReceiverModule_NotAuthorized(_addr);
            }
        }
    }
}
