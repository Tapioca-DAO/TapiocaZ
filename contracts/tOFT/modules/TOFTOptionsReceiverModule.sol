// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {SendParam} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OFTMsgCodec} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/libs/OFTMsgCodec.sol";

// External
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

// Tapioca
import {
    LockAndParticipateData,
    IMagnetar,
    MagnetarCall,
    MagnetarAction
} from "tap-utils/interfaces/periph/IMagnetar.sol";
import {IMagnetarOptionModule} from "tap-utils/interfaces/periph/IMagnetar.sol";
import {
    ITapiocaOptionBroker, IExerciseOptionsData
} from "tap-utils/interfaces/tap-token/ITapiocaOptionBroker.sol";
import {TOFTInitStruct, ExerciseOptionsMsg, LZSendParam} from "tap-utils/interfaces/oft/ITOFT.sol";
import {ITapiocaOmnichainEngine} from "tap-utils/interfaces/periph/ITapiocaOmnichainEngine.sol";
import {SafeApprove} from "tap-utils/libraries/SafeApprove.sol";
import {TOFTMsgCodec} from "../libraries/TOFTMsgCodec.sol";
import {BaseTOFT} from "../BaseTOFT.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

/**
 * @title TOFTOptionsReceiverModule
 * @author TapiocaDAO
 * @notice TOFT Options module
 */
contract TOFTOptionsReceiverModule is BaseTOFT {
    using SafeERC20 for IERC20;
    using SafeCast for uint256;
    using SafeApprove for address;

    error TOFTOptionsReceiverModule_NotAuthorized(address invalidAddress);
    error TOFTOptionsReceiverModule_Reentrancy();

    event ExerciseOptionsReceived(
        address indexed user, address indexed target, uint256 indexed oTapTokenId, uint256 paymentTokenAmount
    );
    event LockAndParticipateReceived(
        address indexed user,
        address indexed srcChainSender,
        bool lock,
        address indexed lockTarget,
        uint256 fraction,
        bool participate,
        address participateTarget
    );

    constructor(TOFTInitStruct memory _data) BaseTOFT(_data) {}

    /**
     * @notice Execute `magnetar.lockAndParticipate`
     * @dev Lock on tOB and/or participate on tOLP
     * @param srcChainSender The address of the sender on the source chain.
     * @param _data The call data containing info about the operation.
     * @param _data.user the user to perform the operation for
     * @param _data.tSglToken The address of the tOFT SGL token
     * @param _data.yieldBox The address of the yield box
     * @param _data.fraction the amount to lock
     * @param _data.lockData the data needed to lock on tOB
     * @param _data.participateData the data needed to participate on tOLP
     */
    function lockAndParticipateReceiver(address srcChainSender, bytes memory _data) public payable {
        // Decode receive message
        LockAndParticipateData memory msg_ = TOFTMsgCodec.decodeLockAndParticipateMsg(_data);

        /**
         * @dev validate data
         */
        msg_ = _validateLockAndParticipate(msg_, srcChainSender);

        /**
         * @dev execute through `Magnetar`
         */
        _lockAndParticipate(msg_);

        emit LockAndParticipateReceived(
            msg_.user,
            srcChainSender,
            msg_.lockData.lock,
            msg_.lockData.target,
            msg_.lockData.fraction,
            msg_.participateData.participate,
            msg_.participateData.target
        );
    }

    /**
     * @notice Exercise tOB option
     * @param srcChainSender The address of the sender on the source chain.
     * @param _data The call data containing info about the operation.
     *      - optionsData::address: TapiocaOptionsBroker exercise params.
     *      - lzSendParams::struct: LZ v2 send to source params.
     *      - composeMsg::bytes: Further compose data.
     */
    function exerciseOptionsReceiver(address srcChainSender, bytes memory _data) public payable {
        // Decode received message.
        ExerciseOptionsMsg memory msg_ = TOFTMsgCodec.decodeExerciseOptionsMsg(_data);

        /**
         * @dev validate data
         */
        msg_ = _validateExerciseOptionReceiver(msg_);

        /**
         * @dev Validate caller
         */
        _validateExerciseOptionCaller(msg_.optionsData, srcChainSender);

        /**
         * @dev retrieve paymentToken amount
         */
        _internalTransferWithAllowance(msg_.optionsData.from, srcChainSender, msg_.optionsData.paymentTokenAmount);

        /**
         * @dev call exerciseOption() with address(this) as the payment token
         */
        // _approve(address(this), _options.target, _options.paymentTokenAmount);
        pearlmit.approve(
            20,
            address(this),
            0,
            msg_.optionsData.target,
            uint200(msg_.optionsData.paymentTokenAmount),
            block.timestamp.toUint48()
        ); // Atomic approval
        _approve(address(this), address(pearlmit), msg_.optionsData.paymentTokenAmount);

        /**
         * @dev exercise and refund if less paymentToken amount was used
         */
        _exerciseAndRefund(msg_.optionsData);
        _approve(address(this), address(pearlmit), 0);

        /**
         * @dev retrieve exercised amount
         */
        _withdrawExercised(msg_);

        emit ExerciseOptionsReceived(
            msg_.optionsData.from,
            msg_.optionsData.target,
            msg_.optionsData.oTAPTokenID,
            msg_.optionsData.paymentTokenAmount
        );
    }

    function _validateLockAndParticipate(LockAndParticipateData memory msg_, address srcChainSender)
        private
        returns (LockAndParticipateData memory)
    {
        _checkWhitelistStatus(msg_.tSglToken);
        _checkWhitelistStatus(msg_.yieldBox);
        _checkWhitelistStatus(msg_.magnetar);
        if (msg_.lockData.lock) {
            _checkWhitelistStatus(msg_.lockData.target);
            if (msg_.lockData.amount > 0) {
                msg_.lockData.amount = _toLD(uint256(msg_.lockData.amount).toUint64()).toUint128();
            }
            if (msg_.lockData.fraction > 0) {
                msg_.lockData.fraction = _toLD(msg_.lockData.fraction.toUint64());
                _validateAndSpendAllowance(msg_.user, srcChainSender, msg_.lockData.fraction);
            }
        }

        if (msg_.participateData.participate) {
            _checkWhitelistStatus(msg_.participateData.target);
        }

        return msg_;
    }

    function _lockAndParticipate(LockAndParticipateData memory msg_) private {
        bytes memory call = abi.encodeWithSelector(IMagnetarOptionModule.lockAndParticipate.selector, msg_);
        MagnetarCall[] memory magnetarCall = new MagnetarCall[](1);
        magnetarCall[0] =
            MagnetarCall({id: uint8(MagnetarAction.OptionModule), target: msg_.magnetar, value: msg.value, call: call});
        IMagnetar(payable(msg_.magnetar)).burst{value: msg_.value}(magnetarCall);
    }

    function _validateExerciseOptionReceiver(ExerciseOptionsMsg memory msg_)
        private
        view
        returns (ExerciseOptionsMsg memory)
    {
        _checkWhitelistStatus(msg_.optionsData.target);

        if (msg_.optionsData.tapAmount > 0) {
            msg_.optionsData.tapAmount = _toLD(msg_.optionsData.tapAmount.toUint64());
        }

        if (msg_.optionsData.paymentTokenAmount > 0) {
            msg_.optionsData.paymentTokenAmount = _toLD(msg_.optionsData.paymentTokenAmount.toUint64());
        }

        return msg_;
    }

    function _exerciseAndRefund(IExerciseOptionsData memory _options) private {
        uint256 bBefore = balanceOf(address(this));

        ITapiocaOptionBroker(_options.target).exerciseOption(
            _options.oTAPTokenID,
            address(this), //payment token
            _options.tapAmount
        );

        // Clear Pearlmit ERC721 allowance post execution
        {
            address oTap = ITapiocaOptionBroker(_options.target).oTAP();
            address oTapOwner = IERC721(oTap).ownerOf(_options.oTAPTokenID);
            pearlmit.clearAllowance(oTapOwner, 721, oTap, _options.oTAPTokenID);
        }

        uint256 bAfter = balanceOf(address(this));

        // Refund if less was used.
        if (bBefore >= bAfter) {
            uint256 diff = bBefore - bAfter;
            if (diff < _options.paymentTokenAmount) {
                IERC20(address(this)).safeTransfer(_options.from, _options.paymentTokenAmount - diff);
            }
        }
    }

    /**
     *   @notice checks that the caller is allowed by the owner of the token
     */
    function _validateExerciseOptionCaller(IExerciseOptionsData memory _options, address _srcChainSender) internal {
        address oTap = ITapiocaOptionBroker(_options.target).oTAP();
        address oTapOwner = IERC721(oTap).ownerOf(_options.oTAPTokenID);
        if (oTapOwner != _srcChainSender || oTapOwner != _options.from) {
            revert TOFTOptionsReceiverModule_NotAuthorized(_options.from);
        }

        bool isAllowed = isERC721Approved(oTapOwner, address(this), oTap, _options.oTAPTokenID);
        if (!isAllowed) revert TOFTOptionsReceiverModule_NotAuthorized(oTapOwner);
        /// @dev Clear the allowance once it's used
        /// usage being the allowance check
        pearlmit.clearAllowance(oTapOwner, 721, oTap, _options.oTAPTokenID);
    }

    function _withdrawExercised(ExerciseOptionsMsg memory msg_) private {
        SendParam memory _send = msg_.lzSendParams.sendParam;

        address tapOft = ITapiocaOptionBroker(msg_.optionsData.target).tapOFT();
        uint256 tapBalance = IERC20(tapOft).balanceOf(address(this));
        if (msg_.withdrawOnOtherChain) {
            /// @dev determine the right amount to send back to source

            uint256 amountToSend = _send.amountLD > tapBalance ? tapBalance : _send.amountLD;
            if (_send.minAmountLD > amountToSend) {
                _send.minAmountLD = amountToSend;
            }
            _send.amountLD = amountToSend;

            msg_.lzSendParams.sendParam = _send;

            ITapiocaOmnichainEngine(tapOft).sendPacketFrom{value: msg.value}(
                msg_.optionsData.from, msg_.lzSendParams, ""
            );

            // Refund extra amounts
            if (tapBalance - amountToSend > 0) {
                IERC20(tapOft).safeTransfer(msg_.optionsData.from, tapBalance - amountToSend);
            }
        } else {
            //send on this chain
            IERC20(tapOft).safeTransfer(msg_.optionsData.from, tapBalance);
        }
    }

    function _checkWhitelistStatus(address _addr) private view {
        if (_addr != address(0)) {
            if (!getCluster().isWhitelisted(0, _addr)) {
                revert TOFTOptionsReceiverModule_NotAuthorized(_addr);
            }
        }
    }
}
