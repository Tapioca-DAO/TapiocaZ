// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.22;

// Tapioca
import {
    YieldBoxApproveAllMsg,
    YieldBoxApproveAssetMsg,
    MarketPermitActionMsg
} from "tapioca-periph/interfaces/periph/ITapiocaOmnichainEngine.sol";
import {ERC20PermitApprovalMsg, ERC20PermitStruct} from "tapioca-periph/interfaces/oft/ITOFT.sol";

import "forge-std/Test.sol";

contract TestUtils is Test {
    /**
     * @dev Helper to build an ERC20PermitApprovalMsg.
     * @param _permit The permit data.
     * @param _digest The typed data digest.
     * @param _token The token contract to receive the permit.
     * @param _pkSigner The private key signer.
     */
    function __getERC20PermitData(ERC20PermitStruct memory _permit, bytes32 _digest, address _token, uint256 _pkSigner)
        internal
        pure
        returns (ERC20PermitApprovalMsg memory permitApproval_)
    {
        (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(_pkSigner, _digest);

        permitApproval_ = ERC20PermitApprovalMsg({
            token: _token,
            owner: _permit.owner,
            spender: _permit.spender,
            value: _permit.value,
            deadline: _permit.deadline,
            v: v_,
            r: r_,
            s: s_
        });
    }

    function __getYieldBoxPermitAllData(
        ERC20PermitStruct memory _permit,
        address _target,
        bool _isPermit,
        bytes32 _digest,
        uint256 _pkSigner
    ) internal pure returns (YieldBoxApproveAllMsg memory permitApproval_) {
        (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(_pkSigner, _digest);

        permitApproval_ = YieldBoxApproveAllMsg({
            target: _target,
            owner: _permit.owner,
            spender: _permit.spender,
            deadline: _permit.deadline,
            v: v_,
            r: r_,
            s: s_,
            permit: _isPermit
        });
    }

    function __getYieldBoxPermitAssetData(
        ERC20PermitStruct memory _permit,
        address _target,
        bool _isPermit,
        bytes32 _digest,
        uint256 _pkSigner
    ) internal pure returns (YieldBoxApproveAssetMsg memory permitApproval_) {
        (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(_pkSigner, _digest);

        permitApproval_ = YieldBoxApproveAssetMsg({
            target: _target,
            owner: _permit.owner,
            spender: _permit.spender,
            assetId: _permit.value,
            deadline: _permit.deadline,
            v: v_,
            r: r_,
            s: s_,
            permit: _isPermit
        });
    }

    function __getMarketPermitData(MarketPermitActionMsg memory _permit, bytes32 _digest, uint256 _pkSigner)
        internal
        pure
        returns (MarketPermitActionMsg memory permitApproval_)
    {
        (uint8 v_, bytes32 r_, bytes32 s_) = vm.sign(_pkSigner, _digest);

        permitApproval_ = MarketPermitActionMsg({
            target: _permit.target,
            owner: _permit.owner,
            spender: _permit.spender,
            value: _permit.value,
            deadline: _permit.deadline,
            v: v_,
            r: r_,
            s: s_,
            permitAsset: _permit.permitAsset
        });
    }
}
