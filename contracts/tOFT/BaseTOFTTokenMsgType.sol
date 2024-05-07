// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

abstract contract BaseTOFTTokenMsgType {
    uint16 internal constant MSG_MARKET_REMOVE_COLLATERAL = 800; // Use for remove collateral from a market available on another chain
    uint16 internal constant MSG_YB_SEND_SGL_BORROW = 801; // Use fror send to YB and/or borrow from a market available on another chain
    uint16 internal constant MSG_TAP_EXERCISE = 802; // Use for exercise options on tOB available on another chain
    uint16 internal constant MSG_SEND_PARAMS = 803; // Use for perform a normal OFT send but with a custom payload
    uint16 internal constant MSG_LOCK_AND_PARTICIPATE = 804; // Use for `magnetar.mintFromBBAndSendForLending` step 3 call
    uint16 internal constant MSG_LEVERAGE_UP = 805; // Use for leveraging up on a market availabl eon another chain
    uint16 internal constant MSG_XCHAIN_LEND_XCHAIN_LOCK = 806; // Use for `magnetar.mintFromBBAndSendForLending` step 2 call
}
