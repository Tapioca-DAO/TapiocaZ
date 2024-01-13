// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

import "tapioca-periph/contracts/interfaces/IPermit.sol";
import "tapioca-periph/contracts/interfaces/IPermitAll.sol";
import "tapioca-periph/contracts/interfaces/IPermitAction.sol";
import "tapioca-periph/contracts/interfaces/ICommonData.sol";

import "../BaseTOFTStorage.sol";

abstract contract TOFTCommon is BaseTOFTStorage {
    // ************** //
    // *** ERRORS *** //
    // ************** //
    error ActionTypeNotValid();
    error NotAuthorized(address invalidAddress);
    error ModuleNotAuthorized();

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
                        revert(_getRevertMsg(reason));
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
                    revert(_getRevertMsg(reason));
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
                    revert(_getRevertMsg(reason));
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
                    revert(_getRevertMsg(reason));
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
                    revert(_getRevertMsg(reason));
                }
            }
        }
    }
}
