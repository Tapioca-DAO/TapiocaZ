// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {SendParam, MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";

// Tapioca
import {ITapiocaOptionBrokerCrossChain} from "tapioca-periph/interfaces/tap-token/ITapiocaOptionBroker.sol";
import {ITapiocaOFT} from "tapioca-periph/interfaces/tap-token/ITapiocaOFT.sol";
import {ICommonData} from "tapioca-periph/interfaces/common/ICommonData.sol";
import {IUSDOBase} from "tapioca-periph/interfaces/bar/IUSDO.sol";

interface ITOFTv2 {
    enum Module {
        NonModule, //0
        TOFTv2Sender,
        TOFTv2Receiver,
        TOFTv2MarketReceiver,
        TOFTv2OptionsReceiver,
        TOFTv2GenericReceiver
    }

    /**
     * =======================
     * LZ functions
     * =======================
     */
    function combineOptions(uint32 _eid, uint16 _msgType, bytes calldata _extraOptions)
        external
        view
        returns (bytes memory);

    /**
     * =======================
     * Tapioca added functions
     * =======================
     */
    function quoteSendPacket(
        SendParam calldata _sendParam,
        bytes calldata _extraOptions,
        bool _payInLzToken,
        bytes calldata _composeMsg,
        bytes calldata /*_oftCmd*/ // @dev unused in the default implementation.
    ) external view returns (MessagingFee memory msgFee);
}

/// =======================
/// ========= LZ ==========
/// =======================

/**
 * @param sendParam The parameters for the send operation.
 * @param fee The calculated fee for the send() operation.
 *      - nativeFee: The native fee.
 *      - lzTokenFee: The lzToken fee.
 * @param _extraOptions Additional options for the send() operation.
 * @param refundAddress The address to refund the native fee to.
 */
struct LZSendParam {
    SendParam sendParam;
    MessagingFee fee;
    bytes extraOptions;
    address refundAddress;
}

/// ============================
/// ========= GENERIC ==========
/// ============================

struct TOFTInitStruct {
    string name;
    string symbol;
    address endpoint;
    address owner;
    address yieldBox;
    address cluster;
    address erc20;
    uint256 hostEid;
}

struct TOFTModulesInitStruct {
    //modules
    address tOFTSenderModule;
    address tOFTReceiverModule;
    address marketReceiverModule;
    address optionsReceiverModule;
    address genericReceiverModule;
}

/// ============================
/// ========= COMPOSE ==========
/// ============================
/**
 * @notice Encodes the message for the PT_SEND_PARAMS operation.
 */
struct SendParamsMsg {
    address receiver; //TODO: decide if we should use `srcChainSender_`
    bool unwrap;
    uint256 amount; //TODO: use the amount credited by lzReceive directly
}

/**
 * @notice Encodes the message for the PT_TAP_EXERCISE operation.
 */
struct ExerciseOptionsMsg {
    ITapiocaOptionBrokerCrossChain.IExerciseOptionsData optionsData;
    bool withdrawOnOtherChain;
    //@dev send back to source message params
    LZSendParam lzSendParams;
    bytes composeMsg;
}

/**
 * @notice Encodes the message for the PT_LEVERAGE_MARKET_DOWN operation.
 */
struct MarketLeverageDownMsg {
    address user;
    uint256 amount;
    IUSDOBase.ILeverageSwapData swapData;
    IUSDOBase.ILeverageExternalContractsData externalData;
    //@dev send back to source message params
    LZSendParam lzSendParams;
    bytes composeMsg;
}

/**
 * @notice Encodes the message for the PT_MARKET_REMOVE_COLLATERAL operation.
 */
struct MarketRemoveCollateralMsg {
    address user;
    ITapiocaOFT.IRemoveParams removeParams;
    ICommonData.IWithdrawParams withdrawParams;
}

/**
 * @notice Encodes the message for the PT_YB_SEND_SGL_BORROW operation.
 */
struct MarketBorrowMsg {
    address user;
    ITapiocaOFT.IBorrowParams borrowParams;
    ICommonData.IWithdrawParams withdrawParams;
}

/**
 * @notice Encodes the message for the ybPermitAll() operation.
 */
struct YieldBoxApproveAllMsg {
    address target;
    address owner;
    address spender;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
    bool permit;
}

/**
 * @notice Encodes the message for the ybPermitAll() operation.
 */
struct YieldBoxApproveAssetMsg {
    address target;
    address owner;
    address spender;
    uint256 assetId;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
    bool permit;
}

/**
 * @notice Encodes the message for the market.permitAction() or market.permitBorrow() operations.
 */
struct MarketPermitActionMsg {
    address target;
    uint16 actionType;
    address owner;
    address spender;
    uint256 value;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
    bool permitAsset;
}

/**
 * @notice Encodes the message for the ercPermitApproval() operation.
 */
struct ERC20PermitApprovalMsg {
    address token;
    address owner;
    address spender;
    uint256 value;
    uint256 deadline;
    uint8 v;
    bytes32 r;
    bytes32 s;
}

/**
 * Structure of an ERC20 permit message.
 */
struct ERC20PermitStruct {
    address owner;
    address spender;
    uint256 value;
    uint256 nonce;
    uint256 deadline;
}

/**
 * @dev Used in TOFTv2Helper.
 */
struct RemoteTransferMsg {
    address owner;
    LZSendParam lzSendParam;
    bytes composeMsg;
}
