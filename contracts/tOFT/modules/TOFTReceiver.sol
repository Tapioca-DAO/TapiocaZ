// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";
import {OFTCore} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFTCore.sol";
import {Origin} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import {OFT} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/OFT.sol";

// External
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Tapioca
import {
    ITOFT,
    TOFTInitStruct,
    YieldBoxApproveAllMsg,
    MarketPermitActionMsg,
    YieldBoxApproveAssetMsg
} from "tapioca-periph/interfaces/oft/ITOFT.sol";
import {TapiocaOmnichainReceiver} from "tapioca-periph/tapiocaOmnichainEngine/TapiocaOmnichainReceiver.sol";
import {TOFTMarketReceiverModule} from "./TOFTMarketReceiverModule.sol";
import {TOFTOptionsReceiverModule} from "./TOFTOptionsReceiverModule.sol";
import {TOFTGenericReceiverModule} from "./TOFTGenericReceiverModule.sol";
import {TOFTMsgCodec} from "contracts/tOFT/libraries/TOFTMsgCodec.sol";
import {BaseTOFT} from "contracts/tOFT/BaseTOFT.sol";

import "forge-std/console.sol";

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

contract TOFTReceiver is BaseTOFT, TapiocaOmnichainReceiver {
    using OFTMsgCodec for bytes;
    using OFTMsgCodec for bytes32;
    using SafeERC20 for IERC20;

    error InvalidApprovalTarget(address _target);

    constructor(TOFTInitStruct memory _data) BaseTOFT(_data) {}

    /**
     * @inheritdoc TapiocaOmnichainReceiver
     */
    function _lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor, /*_executor*/ // @dev unused in the default implementation.
        bytes calldata _extraData /*_extraData*/ // @dev unused in the default implementation.
    ) internal virtual override(OFTCore, TapiocaOmnichainReceiver) {
        TapiocaOmnichainReceiver._lzReceive(_origin, _guid, _message, _executor, _extraData);
    }

    /**
     * @inheritdoc TapiocaOmnichainReceiver
     */
    function _toeComposeReceiver(uint16 _msgType, address _srcChainSender, bytes memory _toeComposeMsg)
        internal
        override
        returns (bool success)
    {
        if (_msgType == MSG_MARKET_PERMIT) {
            _marketPermitReceiver(_toeComposeMsg);
        } else if (_msgType == MSG_YB_SEND_SGL_BORROW) {
            _executeModule(
                uint8(ITOFT.Module.TOFTMarketReceiver),
                abi.encodeWithSelector(TOFTMarketReceiverModule.marketBorrowReceiver.selector, _toeComposeMsg),
                false
            );
        } else if (_msgType == MSG_MARKET_REMOVE_COLLATERAL) {
            _executeModule(
                uint8(ITOFT.Module.TOFTMarketReceiver),
                abi.encodeWithSelector(TOFTMarketReceiverModule.marketRemoveCollateralReceiver.selector, _toeComposeMsg),
                false
            );
        } else if (_msgType == MSG_TAP_EXERCISE) {
            _executeModule(
                uint8(ITOFT.Module.TOFTOptionsReceiver),
                abi.encodeWithSelector(
                    TOFTOptionsReceiverModule.exerciseOptionsReceiver.selector, _srcChainSender, _toeComposeMsg
                ),
                false
            );
        } else if (_msgType == MSG_SEND_PARAMS) {
            _executeModule(
                uint8(ITOFT.Module.TOFTGenericReceiver),
                abi.encodeWithSelector(
                    TOFTGenericReceiverModule.receiveWithParamsReceiver.selector, _srcChainSender, _toeComposeMsg
                ),
                false
            );
        } else if (_msgType == MSG_YB_APPROVE_ALL) {
            _yieldBoxPermitAllReceiver(_toeComposeMsg);
        } else if (_msgType == MSG_YB_APPROVE_ASSET) {
            _yieldBoxPermitAssetReceiver(_toeComposeMsg);
        } else if (_msgType == MSG_MARKET_PERMIT) {
            _marketPermitReceiver(_toeComposeMsg);
        } else {
            return false;
        }
        return true;
    }
    // ********************* //
    // ***** RECEIVERS ***** //
    // ********************* //
    /**
     * @notice Approves YieldBox asset via permit.
     * @param _data The call data containing info about the approvals.
     *      - token::address: Address of the YieldBox to approve.
     *      - owner::address: Address of the owner of the tokens.
     *      - spender::address: Address of the spender.
     *      - value::uint256: Amount of tokens to approve.
     *      - deadline::uint256: Deadline for the approval.
     *      - v::uint8: v value of the signature.
     *      - r::bytes32: r value of the signature.
     *      - s::bytes32: s value of the signature.
     */

    function _yieldBoxPermitAssetReceiver(bytes memory _data) internal virtual {
        YieldBoxApproveAssetMsg[] memory approvals = TOFTMsgCodec.decodeArrayOfYieldBoxPermitAssetMsg(_data);

        uint256 approvalsLength = approvals.length;
        for (uint256 i = 0; i < approvalsLength;) {
            _sanitizeTarget(approvals[i].target);
            unchecked {
                ++i;
            }
        }

        toftExtExec.yieldBoxPermitApproveAsset(approvals);
    }

    /**
     * @notice Approves all assets on YieldBox.
     * @param _data The call data containing info about the approval.
     *      - target::address: Address of the YieldBox contract.
     *      - owner::address: Address of the owner of the tokens.
     *      - spender::address: Address of the spender.
     *      - deadline::uint256: Deadline for the approval.
     *      - v::uint8: v value of the signature.
     *      - r::bytes32: r value of the signature.
     *      - s::bytes32: s value of the signature.
     */
    function _yieldBoxPermitAllReceiver(bytes memory _data) internal virtual {
        console.log("--------------A");
        YieldBoxApproveAllMsg memory approval = TOFTMsgCodec.decodeYieldBoxApproveAllMsg(_data);
        console.log("--------------B");

        _sanitizeTarget(approval.target);
        console.log("--------------C");

        if (approval.permit) {
            console.log("--------------D");
            toftExtExec.yieldBoxPermitApproveAll(approval);
            console.log("--------------E");
        } else {
            console.log("--------------F");
            toftExtExec.yieldBoxPermitRevokeAll(approval);
            console.log("--------------G");
        }
    }

    /**
     * @notice Approves Market lend/borrow via permit.
     * @param _data The call data containing info about the approval.
     *      - token::address: Address of the YieldBox to approve.
     *      - owner::address: Address of the owner of the tokens.
     *      - spender::address: Address of the spender.
     *      - value::uint256: Amount of tokens to approve.
     *      - deadline::uint256: Deadline for the approval.
     *      - v::uint8: v value of the signature.
     *      - r::bytes32: r value of the signature.
     *      - s::bytes32: s value of the signature.
     */
    function _marketPermitReceiver(bytes memory _data) internal virtual {
        MarketPermitActionMsg memory approval = TOFTMsgCodec.decodeMarketPermitApprovalMsg(_data);

        _sanitizeTarget(approval.target);

        if (approval.permitAsset) {
            toftExtExec.marketPermitAssetApproval(approval);
        } else {
            toftExtExec.marketPermitCollateralApproval(approval);
        }
    }

    function _sanitizeTarget(address target) private view {
        if (!cluster.isWhitelisted(0, target)) {
            revert InvalidApprovalTarget(target);
        }
    }
}
