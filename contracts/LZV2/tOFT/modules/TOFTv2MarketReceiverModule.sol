// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol";

// External
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BytesLib} from "solidity-bytes-utils/contracts/BytesLib.sol";

// Tapioca
import {ITapiocaOFT} from "tapioca-periph/contracts/interfaces/ITapiocaOFT.sol";
import {IMagnetar} from "tapioca-periph/contracts/interfaces/IMagnetar.sol";
import {TOFTv2CommonReceiverModule} from "contracts/modules/TOFTv2CommonReceiverModule.sol";
import {IUSDOBase} from "tapioca-periph/contracts/interfaces/IUSDO.sol";
import {IMarket} from "tapioca-periph/contracts/interfaces/IMarket.sol";
import {TOFTMsgCoder} from "contracts/libraries/TOFTMsgCoder.sol";
import {TOFTInitStruct, MarketBorrowMsg} from "contracts/ITOFTv2.sol";
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

/**
 * @title TOFTv2MarketReceiverModule
 * @author TapiocaDAO
 * @notice TOFTv2 Market module
 */
contract TOFTv2MarketReceiverModule is BaseTOFTv2, TOFTv2CommonReceiverModule {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    error TOFTv2MarketReceiverModule_AllowanceNotValid();
    error TOFTv2MarketReceiverModule_NotAuthorized(address invalidAddress);

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
        if (msg.sender != address(this))
            revert TOFTv2MarketReceiverModule_NotAuthorized(msg.sender);

        // @dev decode received message
        MarketBorrowMsg memory marketBorrowMsg_ = TOFTMsgCoder
            .decodeMarketBorrowMsg(_data);

        // @dev sanitize 'borrowParams.marketHelper' and 'borrowParams.market'
        if (
            !cluster.isWhitelisted(
                0,
                marketBorrowMsg_.borrowParams.marketHelper
            )
        )
            revert TOFTv2MarketReceiverModule_NotAuthorized(
                marketBorrowMsg_.borrowParams.marketHelper
            );

        if (!cluster.isWhitelisted(0, marketBorrowMsg_.borrowParams.market))
            revert TOFTv2MarketReceiverModule_NotAuthorized(
                marketBorrowMsg_.borrowParams.market
            );

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
            true,
            true,
            marketBorrowMsg_.withdrawParams
        );

        // TODO:???? do we need an event here?
    }
}