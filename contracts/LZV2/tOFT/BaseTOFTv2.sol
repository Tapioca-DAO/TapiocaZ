// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {ExecutorOptions} from "@layerzerolabs/lz-evm-protocol-v2/contracts/messagelib/libs/ExecutorOptions.sol";
import {IOAppMsgInspector} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppMsgInspector.sol";
import {IMessagingChannel} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessagingChannel.sol";
import {SendParam, MessagingFee} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";

// External
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BytesLib} from "@layerzerolabs/solidity-bytes-utils/contracts/BytesLib.sol";

// Tapioca
import {IYieldBoxBase} from "tapioca-periph/contracts/interfaces/IYieldBoxBase.sol";
import {ICluster} from "tapioca-periph/contracts/interfaces/ICluster.sol";
import {TOFTv2ExtExec} from "./extensions/TOFTv2ExtExec.sol";
import {ModuleManager} from "./modules/ModuleManager.sol";
import {ITOFTv2, TOFTInitStruct} from "./ITOFTv2.sol";
import {CommonOFTv2} from "./CommonOFTv2.sol";
import {TOFTVault} from "../../tOFT/TOFTVault.sol";

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
 * @title BaseTOFTv2
 * @author TapiocaDAO
 * @notice Base TOFT contract for LZ V2
 */
contract BaseTOFTv2 is CommonOFTv2, ModuleManager {
    using BytesLib for bytes;
    using SafeERC20 for IERC20;
    using OFTMsgCodec for bytes;
    using OFTMsgCodec for bytes32;

    // LZ packets
    uint16 internal constant PT_REMOTE_TRANSFER = 400; // Use for transferring tokens from the contract from another chain

    uint16 internal constant PT_APPROVALS = 500; // Use for ERC20Permit approvals
    uint16 internal constant PT_NFT_APPROVALS = 501; // Use for ERC721Permit approvals; TODO: check if we need this
    uint16 internal constant PT_YB_APROVE_ASSET = 502; // Use for YieldBox 'setApprovalForAsset(true)' operation
    uint16 internal constant PT_YB_APPROVE_ALL = 503; // Use for YieldBox 'setApprovalForAll(true)' operation
    uint16 internal constant PT_YB_REVOKE_ASSET = 504; // Use for YieldBox 'setApprovalForAsset(false)' operation
    uint16 internal constant PT_YB_REVOKE_ALL = 505; // Use for YieldBox 'setApprovalForAll(false)' operation
    uint16 internal constant PT_MARKET_PERMIT_LEND = 506; // Use for market.permitLend() operation
    uint16 internal constant PT_MARKET_PERMIT_BORROW = 506; // Use for market.permitBorrow() operation

    uint16 internal constant PT_MARKET_REMOVE_COLLATERAL = 700; // Use for remove collateral from a market available on another chain
    uint16 internal constant PT_YB_SEND_SGL_BORROW = 701; // Use fror send to YB and/or borrow from a market available on another chain
    uint16 internal constant PT_LEVERAGE_MARKET_DOWN = 702; // Use for leverage sell on a market available on another chain
    uint16 internal constant PT_TAP_EXERCISE = 703; // Use for exercise options on tOB available on another chain
    uint16 internal constant PT_SEND_PARAMS = 704; // Use for perform a normal OFT send but with a custom payload

    /// @dev Used to execute certain extern calls from the TOFTv2 contract, such as ERC20Permit approvals.
    TOFTv2ExtExec public immutable toftV2ExtExec;
    IYieldBoxBase public immutable yieldBox;
    TOFTVault public immutable vault;
    uint256 public immutable hostEid;
    address public immutable erc20;
    ICluster public cluster;

    uint256 internal constant SLIPPAGE_PRECISION = 1e4;

    error InvalidMsgType(uint16 msgType); // Triggered if the msgType is invalid on an `_lzCompose`.
    error TOFT_AllowanceNotValid();
    error TOFT_NotValid();

    constructor(
        TOFTInitStruct memory _data
    ) CommonOFTv2(_data.name, _data.symbol, _data.endpoint, _data.owner) {
        yieldBox = IYieldBoxBase(_data.yieldBox);
        cluster = ICluster(_data.cluster);
        hostEid = _data.hostEid;
        erc20 = _data.erc20;
        vault = TOFTVault(_data.tOFTVault);

        toftV2ExtExec = new TOFTv2ExtExec();

        // Set TOFTv2 execution modules
        if (_data.tOFTSenderModule == address(0)) revert TOFT_NotValid();
        if (_data.tOFTReceiverModule == address(0)) revert TOFT_NotValid();
        if (_data.marketReceiverModule == address(0)) revert TOFT_NotValid();

        _setModule(uint8(ITOFTv2.Module.TOFTv2Sender), _data.tOFTSenderModule);
        _setModule(
            uint8(ITOFTv2.Module.TOFTv2Receiver),
            _data.tOFTReceiverModule
        );
        _setModule(
            uint8(ITOFTv2.Module.TOFTv2MarketReceiver),
            _data.marketReceiverModule
        );
    }

    /**
     * @notice set the Cluster address.
     * @param _cluster the new Cluster address
     */
    function setCluster(address _cluster) external virtual {}

    /**
     * @notice Return the current chain EID.
     */
    function _getChainId() internal view override returns (uint32) {
        return IMessagingChannel(endpoint).eid();
    }

    function _wrap(
        address _fromAddress,
        address _toAddress,
        uint256 _amount,
        uint256 _feeAmount
    ) internal virtual {
        if (_fromAddress != msg.sender) {
            if (allowance(_fromAddress, msg.sender) < _amount)
                revert TOFT_AllowanceNotValid();
            _spendAllowance(_fromAddress, msg.sender, _amount);
        }
        if (_amount == 0) revert TOFT_NotValid();
        IERC20(erc20).safeTransferFrom(_fromAddress, address(vault), _amount);
        _mint(_toAddress, _amount - _feeAmount);
    }

    function _wrapNative(
        address _toAddress,
        uint256 _amount,
        uint256 _feeAmount
    ) internal virtual {
        vault.depositNative{value: _amount}();
        _mint(_toAddress, _amount - _feeAmount);
    }

    function _unwrap(address _toAddress, uint256 _amount) internal virtual {
        _burn(msg.sender, _amount);
        vault.withdraw(_toAddress, _amount);
    }
}
