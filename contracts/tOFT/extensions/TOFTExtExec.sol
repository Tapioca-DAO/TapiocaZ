// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// Tapioca
import {
    YieldBoxApproveAllMsg,
    MarketPermitActionMsg,
    YieldBoxApproveAssetMsg
} from "tapioca-periph/interfaces/oft/ITOFT.sol";
import {TapiocaOmnichainExtExec} from "tapioca-periph/tapiocaOmnichainEngine/extension/TapiocaOmnichainExtExec.sol";
import {IPermitBorrow} from "tapioca-periph/interfaces/common/IPermitBorrow.sol";
import {IPermitAll} from "tapioca-periph/interfaces/common/IPermitAll.sol";
import {IPermit} from "tapioca-periph/interfaces/common/IPermit.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

/**
 * @title TOFTExtExec
 * @author TapiocaDAO
 * @notice Used to execute external calls from the TOFT contract. So to not use TOFT in the call context.
 */
contract TOFTExtExec is TapiocaOmnichainExtExec {
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
    function yieldBoxPermitApproveAsset(YieldBoxApproveAssetMsg[] calldata _approvals) public {
        uint256 approvalsLength = _approvals.length;
        for (uint256 i = 0; i < approvalsLength;) {
            // @dev token is YieldBox
            if (!_approvals[i].permit) {
                IPermit(_approvals[i].target).revoke(
                    _approvals[i].owner,
                    _approvals[i].spender,
                    _approvals[i].assetId,
                    _approvals[i].deadline,
                    _approvals[i].v,
                    _approvals[i].r,
                    _approvals[i].s
                );
            } else {
                IPermit(_approvals[i].target).permit(
                    _approvals[i].owner,
                    _approvals[i].spender,
                    _approvals[i].assetId,
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
    function marketPermitAssetApproval(MarketPermitActionMsg calldata _approval) public {
        IPermit(_approval.target).permit(
            _approval.owner,
            _approval.spender,
            _approval.value,
            _approval.deadline,
            _approval.v,
            _approval.r,
            _approval.s
        );
    }

    /**
     * @notice Executes SGL/BB permitBorrow operation.
     * @param _approval The approval message.
     */
    function marketPermitCollateralApproval(MarketPermitActionMsg calldata _approval) public {
        IPermitBorrow(_approval.target).permitBorrow(
            _approval.owner,
            _approval.spender,
            _approval.value,
            _approval.deadline,
            _approval.v,
            _approval.r,
            _approval.s
        );
    }
}
