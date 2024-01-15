// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

//OZ
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

// Tapioca
import {IPermitAction} from "tapioca-periph/contracts/interfaces/IPermitAction.sol";
import {ICommonData} from "tapioca-periph/contracts/interfaces/ICommonData.sol";
import {IPermitAll} from "tapioca-periph/contracts/interfaces/IPermitAll.sol";
import {IPermit} from "tapioca-periph/contracts/interfaces/IPermit.sol";
import {RevertMsgDecoder} from "../libraries/RevertMsgDecoder.sol";

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

//TODO:???? refactor?
//TODO:???? use TOFTv2ExtExec for approval logic
contract TOFTv2CommonReceiverModule {
    error ActionTypeNotValid();

    function _callApproval(
        ICommonData.IApproval[] memory approvals,
        uint16 actionType
    ) internal {
        for (uint256 i = 0; i < approvals.length; ) {
            if (approvals[i].yieldBoxTypeApproval) {
                if (approvals[i].revokeYieldBox) {
                    _revokeOnYieldBox(approvals[i]);
                } else {
                    _permitOnYieldBox(approvals[i]);
                }
            } else {
                if (approvals[i].actionType != actionType)
                    revert ActionTypeNotValid();
                bytes memory sigData = abi.encode(
                    approvals[i].permitBorrow,
                    approvals[i].owner,
                    approvals[i].spender,
                    approvals[i].value,
                    approvals[i].deadline,
                    approvals[i].v,
                    approvals[i].r,
                    approvals[i].s
                );
                try
                    IPermitAction(approvals[i].target).permitAction(
                        sigData,
                        approvals[i].actionType
                    )
                {} catch Error(string memory reason) {
                    if (!approvals[i].allowFailure) {
                        revert(reason);
                    }
                } catch (bytes memory reason) {
                    if (!approvals[i].allowFailure) {
                        revert(RevertMsgDecoder._getRevertMsg(reason));
                    }
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    function _revokeOnYieldBox(ICommonData.IApproval memory approval) private {
        if (approval.permitAll) {
            try
                IPermitAll(approval.target).revokeAll(
                    approval.owner,
                    approval.spender,
                    approval.deadline,
                    approval.v,
                    approval.r,
                    approval.s
                )
            {} catch Error(string memory reason) {
                if (!approval.allowFailure) {
                    revert(reason);
                }
            } catch (bytes memory reason) {
                if (!approval.allowFailure) {
                    revert(RevertMsgDecoder._getRevertMsg(reason));
                }
            }
        } else {
            try
                IPermit(approval.target).revoke(
                    approval.owner,
                    approval.spender,
                    approval.value,
                    approval.deadline,
                    approval.v,
                    approval.r,
                    approval.s
                )
            {} catch Error(string memory reason) {
                if (!approval.allowFailure) {
                    revert(reason);
                }
            } catch (bytes memory reason) {
                if (!approval.allowFailure) {
                    revert(RevertMsgDecoder._getRevertMsg(reason));
                }
            }
        }
    }

    function _permitOnYieldBox(ICommonData.IApproval memory approval) private {
        if (approval.permitAll) {
            try
                IPermitAll(approval.target).permitAll(
                    approval.owner,
                    approval.spender,
                    approval.deadline,
                    approval.v,
                    approval.r,
                    approval.s
                )
            {} catch Error(string memory reason) {
                if (!approval.allowFailure) {
                    revert(reason);
                }
            } catch (bytes memory reason) {
                if (!approval.allowFailure) {
                    revert(RevertMsgDecoder._getRevertMsg(reason));
                }
            }
        } else {
            try
                IERC20Permit(approval.target).permit(
                    approval.owner,
                    approval.spender,
                    approval.value,
                    approval.deadline,
                    approval.v,
                    approval.r,
                    approval.s
                )
            {} catch Error(string memory reason) {
                if (!approval.allowFailure) {
                    revert(reason);
                }
            } catch (bytes memory reason) {
                if (!approval.allowFailure) {
                    revert(RevertMsgDecoder._getRevertMsg(reason));
                }
            }
        }
    }
}
