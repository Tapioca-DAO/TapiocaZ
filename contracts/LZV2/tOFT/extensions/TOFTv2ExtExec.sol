// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// OZ
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

// Tapioca
import {
    ERC20PermitApprovalMsg,
    ERC20PermitApprovalMsg,
    LZSendParam,
    YieldBoxApproveAllMsg,
    MarketPermitActionMsg,
    ERC20PermitStruct
} from "contracts/ITOFTv2.sol";
import {IPermit} from "tapioca-periph/contracts/interfaces/IPermit.sol";
import {IPermitAll} from "tapioca-periph/contracts/interfaces/IPermitAll.sol";
import {IPermitAction} from "tapioca-periph/contracts/interfaces/IPermitAction.sol";

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
 * @title TOFTv2ExtExec
 * @author TapiocaDAO
 * @notice Used to execute external calls from the TOFTv2 contract. So to not use TOFTv2 in the call context.
 */
contract TOFTv2ExtExec {
    /**
     * @notice Executes YieldBox setApprovalForAll(true) operation.
     * @param _approval The approval message.
     */
    function yieldBoxPermitApproveAll(YieldBoxApproveAllMsg calldata _approval) public {
        IPermitAll(_approval.target).permitAll(
            _approval.owner, _approval.spender, _approval.deadline, _approval.v, _approval.r, _approval.s
        );
    }

    /**
     * @notice Executes YieldBox setApprovalForAll(false) operation.
     * @param _approval The approval message.
     */
    function yieldBoxPermitRevokeAll(YieldBoxApproveAllMsg calldata _approval) public {
        IPermitAll(_approval.target).revokeAll(
            _approval.owner, _approval.spender, _approval.deadline, _approval.v, _approval.r, _approval.s
        );
    }

    /**
     * @notice Executes YieldBox setApprovalForAsset(true) operations.
     * @dev similar to IERC20Permit
     * @param _approvals The approvals message.
     */
    function yieldBoxPermitApproveAsset(ERC20PermitApprovalMsg[] calldata _approvals) public {
        uint256 approvalsLength = _approvals.length;
        for (uint256 i = 0; i < approvalsLength;) {
            // @dev token is YieldBox
            if (_approvals[i].value == 0) {
                IPermit(_approvals[i].token).revoke(
                    _approvals[i].owner,
                    _approvals[i].spender,
                    _approvals[i].value,
                    _approvals[i].deadline,
                    _approvals[i].v,
                    _approvals[i].r,
                    _approvals[i].s
                );
            } else {
                IPermit(_approvals[i].token).permit(
                    _approvals[i].owner,
                    _approvals[i].spender,
                    _approvals[i].value,
                    _approvals[i].deadline,
                    _approvals[i].v,
                    _approvals[i].r,
                    _approvals[i].s
                );
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Executes SGL/BB permitLend operation.
     * @param _approval The approval message.
     */
    function marketPermitLendApproval(MarketPermitActionMsg calldata _approval) public {
        bytes memory sigData = abi.encode(
            false,
            _approval.owner,
            _approval.spender,
            _approval.value,
            _approval.deadline,
            _approval.v,
            _approval.r,
            _approval.s
        );

        IPermitAction(_approval.target).permitAction(sigData, _approval.actionType);
    }

    /**
     * @notice Executes SGL/BB permitBorrow operation.
     * @param _approval The approval message.
     */
    function marketPermitBorrowApproval(MarketPermitActionMsg calldata _approval) public {
        bytes memory sigData = abi.encode(
            true,
            _approval.owner,
            _approval.spender,
            _approval.value,
            _approval.deadline,
            _approval.v,
            _approval.r,
            _approval.s
        );

        IPermitAction(_approval.target).permitAction(sigData, _approval.actionType);
    }

    /**
     * @notice Executes an ERC20 permit approval.
     * @param _approvals The ERC20 permit approval messages.
     */
    function erc20PermitApproval(ERC20PermitApprovalMsg[] calldata _approvals) public {
        uint256 approvalsLength = _approvals.length;
        for (uint256 i = 0; i < approvalsLength;) {
            IERC20Permit(_approvals[i].token).permit(
                _approvals[i].owner,
                _approvals[i].spender,
                _approvals[i].value,
                _approvals[i].deadline,
                _approvals[i].v,
                _approvals[i].r,
                _approvals[i].s
            );
            unchecked {
                ++i;
            }
        }
    }
}
