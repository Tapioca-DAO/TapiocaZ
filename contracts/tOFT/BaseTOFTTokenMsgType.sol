// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

abstract contract BaseTOFTTokenMsgType {
    uint16 internal constant MSG_YB_APPROVE_ASSET = 600; // Use for YieldBox 'setApprovalForAsset(true)' operation
    uint16 internal constant MSG_YB_APPROVE_ALL = 601; // Use for YieldBox 'setApprovalForAll(true)' operation
    uint16 internal constant MSG_MARKET_PERMIT = 602; // Use for market.permitLend() operation

    uint16 internal constant MSG_MARKET_REMOVE_COLLATERAL = 800; // Use for remove collateral from a market available on another chain
    uint16 internal constant MSG_YB_SEND_SGL_BORROW = 801; // Use fror send to YB and/or borrow from a market available on another chain
    uint16 internal constant MSG_LEVERAGE_MARKET_DOWN = 802; // Use for leverage sell on a market available on another chain
    uint16 internal constant MSG_TAP_EXERCISE = 803; // Use for exercise options on tOB available on another chain
    uint16 internal constant MSG_SEND_PARAMS = 804; // Use for perform a normal OFT send but with a custom payload
}
