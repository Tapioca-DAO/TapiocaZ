// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// LZ
import {
    MessagingReceipt, OFTReceipt, SendParam
} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {IOAppMsgInspector} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/interfaces/IOAppMsgInspector.sol";
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
} from "tapioca-periph/interfaces/periph/IMagnetar.sol";
import {MagnetarOptionModule} from "tapioca-periph/Magnetar/modules/MagnetarOptionModule.sol";
import {
    ITapiocaOptionBroker, IExerciseOptionsData
} from "tapioca-periph/interfaces/tap-token/ITapiocaOptionBroker.sol";
import {TOFTInitStruct, ExerciseOptionsMsg, LZSendParam} from "tapioca-periph/interfaces/oft/ITOFT.sol";
import {MagnetarMintXChainModule} from "tapioca-periph/Magnetar/modules/MagnetarMintXChainModule.sol";
import {SafeApprove} from "tapioca-periph/libraries/SafeApprove.sol";
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
     * <<<<<<< HEAD
     * =======
     * @notice cross-chain receiver to deposit mint from BB, lend on SGL, lock on tOLP and participate on tOB
     * @dev Cross chain flow:
     *  step 1: magnetar.mintBBLendXChainSGL (chain A) -->
     *         step 2: IUsdo compose call calls magnetar.depositYBLendSGLLockXchainTOLP (chain B) -->
     *              step 3: IToft(sglReceipt) compose call calls magnetar.lockAndParticipate (chain X)
     * @param srcChainSender The address of the sender on the source chain.
     * @param _data.user the user to perform the operation for
     * @param _data.bigBang the BB address
     * @param _data.mintData the data needed to mint on BB
     * @param _data.lendSendParams LZ send params for lending on another layer
     */
    function mintLendXChainSGLXChainLockAndParticipateReceiver(address srcChainSender, bytes memory _data)
        public
        payable
    {
        // Decode received message.
        CrossChainMintFromBBAndLendOnSGLData memory msg_ =
            TOFTMsgCodec.decodeMintLendXChainSGLXChainLockAndParticipateMsg(_data);

        _checkWhitelistStatus(msg_.bigBang);
        _checkWhitelistStatus(msg_.magnetar);

        if (msg_.mintData.mintAmount > 0) {
            msg_.mintData.mintAmount = _toLD(msg_.mintData.mintAmount.toUint64());
        }
        if (msg_.mintData.collateralDepositData.amount > 0) {
            msg_.mintData.collateralDepositData.amount = _toLD(msg_.mintData.collateralDepositData.amount.toUint64());
        }

        if (msg_.user != srcChainSender) {
            _spendAllowance(msg_.user, srcChainSender, msg_.mintData.mintAmount);
        }

        bytes memory call = abi.encodeWithSelector(MagnetarMintXChainModule.mintBBLendXChainSGL.selector, msg_);
        MagnetarCall[] memory magnetarCall = new MagnetarCall[](1);
        magnetarCall[0] = MagnetarCall({
            id: uint8(MagnetarAction.MintXChainModule),
            target: address(this),
            value: msg.value,
            call: call
        });
        IMagnetar(payable(msg_.magnetar)).burst{value: msg.value}(magnetarCall);
    }

    /**
     * >>>>>>> parent of 0421756 (chore: magnetar references)
     * @notice Execute `magnetar.lockAndParticipate`
     * @dev Lock on tOB and/or participate on tOLP
     * @param srcChainSender The address of the sender on the source chain.
     * @param _data The call data containing info about the operation.
     * @param _data.user the user to perform the operation for
     * @param _data.singularity the SGL address
     * @param _data.fraction the amount to lock
     * @param _data.lockData the data needed to lock on tOB
     * @param _data.participateData the data needed to participate on tOLP
     */
    function lockAndParticipateReceiver(address srcChainSender, bytes memory _data) public payable {
        // Decode receive message
        LockAndParticipateData memory msg_ = TOFTMsgCodec.decodeLockAndParticipateMsg(_data);

        _checkWhitelistStatus(msg_.magnetar);
        _checkWhitelistStatus(msg_.singularity);
        if (msg_.lockData.lock) {
            _checkWhitelistStatus(msg_.lockData.target);
            if (msg_.lockData.amount > 0) {
                msg_.lockData.amount = _toLD(uint256(msg_.lockData.amount).toUint64()).toUint128();
            }
            if (msg_.lockData.fraction > 0) msg_.lockData.fraction = _toLD(msg_.lockData.fraction.toUint64());
        }
        if (msg_.participateData.participate) {
            _checkWhitelistStatus(msg_.participateData.target);
        }

        if (msg_.fraction > 0) {
            msg_.fraction = _toLD(msg_.fraction.toUint64());
        }

        if (msg_.user != srcChainSender) {
            _spendAllowance(msg_.user, srcChainSender, msg_.fraction);
        }

        bytes memory call = abi.encodeWithSelector(MagnetarMintXChainModule.lockAndParticipate.selector, msg_);
        MagnetarCall[] memory magnetarCall = new MagnetarCall[](1);
        magnetarCall[0] = MagnetarCall({
            id: uint8(MagnetarAction.MintXChainModule),
            target: msg_.magnetar,
            value: msg.value,
            call: call
        });
        IMagnetar(payable(msg_.magnetar)).burst{value: msg.value}(magnetarCall);
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
         * @dev retrieve paymentToken amount
         */
        _internalTransferWithAllowance(msg_.optionsData.from, srcChainSender, msg_.optionsData.paymentTokenAmount);

        /**
         * @dev call exerciseOption() with address(this) as the payment token
         */
        pearlmit.approve(
            address(this),
            0,
            msg_.optionsData.target,
            uint200(msg_.optionsData.paymentTokenAmount),
            uint48(block.timestamp + 1)
        ); // Atomic approval
        address(this).safeApprove(address(pearlmit), msg_.optionsData.paymentTokenAmount);

        /**
         * @dev exercise and refund if less paymentToken amount was used
         */
        _exerciseAndRefund(msg_.optionsData);

        /**
         * @dev retrieve exercised amount
         */
        _withdrawExercised(msg_, srcChainSender);

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
        _checkWhitelistStatus(msg_.magnetar);
        _checkWhitelistStatus(msg_.singularity);
        if (msg_.lockData.lock) {
            _checkWhitelistStatus(msg_.lockData.target);
            if (msg_.lockData.amount > 0) {
                msg_.lockData.amount = _toLD(uint256(msg_.lockData.amount).toUint64()).toUint128();
            }
            if (msg_.lockData.fraction > 0) msg_.lockData.fraction = _toLD(msg_.lockData.fraction.toUint64());
        }

        if (msg_.participateData.participate) {
            _checkWhitelistStatus(msg_.participateData.target);
        }

        _validateAndSpendAllowance(msg_.user, srcChainSender, msg_.lockData.fraction);

        return msg_;
    }

    function _lockAndParticipate(LockAndParticipateData memory msg_) private {
        bytes memory call = abi.encodeWithSelector(MagnetarOptionModule.lockAndParticipate.selector, msg_);
        MagnetarCall[] memory magnetarCall = new MagnetarCall[](1);
        magnetarCall[0] =
            MagnetarCall({id: uint8(MagnetarAction.OptionModule), target: msg_.magnetar, value: msg.value, call: call});
        IMagnetar(payable(msg_.magnetar)).burst{value: msg.value}(magnetarCall);
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
        address oTap = ITapiocaOptionBroker(_options.target).oTAP();
        address oTapOwner = IERC721(oTap).ownerOf(_options.oTAPTokenID);

        if (
            oTapOwner != _options.from && !IERC721(oTap).isApprovedForAll(oTapOwner, _options.from)
                && IERC721(oTap).getApproved(_options.oTAPTokenID) != _options.from
        ) revert TOFTOptionsReceiverModule_NotAuthorized(oTapOwner);
        ITapiocaOptionBroker(_options.target).exerciseOption(
            _options.oTAPTokenID,
            address(this), //payment token
            _options.tapAmount
        );
        _approve(address(this), address(pearlmit), 0);
        uint256 bAfter = balanceOf(address(this));

        // Refund if less was used.
        if (bBefore >= bAfter) {
            uint256 diff = bBefore - bAfter;
            if (diff < _options.paymentTokenAmount) {
                IERC20(address(this)).safeTransfer(_options.from, _options.paymentTokenAmount - diff);
            }
        }
    }

    function _withdrawExercised(ExerciseOptionsMsg memory msg_, address srcChainSender) private {
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

            _sendPacket(msg_.lzSendParams, "", srcChainSender);

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

    function _sendPacket(LZSendParam memory _lzSendParam, bytes memory _composeMsg, address _srcChainSender)
        private
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt)
    {
        /// @dev Applies the token transfers regarding this send() operation.
        // - amountDebitedLD is the amount in local decimals that was ACTUALLY debited from the sender.
        // - amountToCreditLD is the amount in local decimals that will be credited to the recipient on the remote OFT instance.
        (uint256 amountDebitedLD, uint256 amountToCreditLD) = _debit(
            msg.sender,
            _lzSendParam.sendParam.amountLD,
            _lzSendParam.sendParam.minAmountLD,
            _lzSendParam.sendParam.dstEid
        );

        /// @dev Builds the options and OFT message to quote in the endpoint.
        (bytes memory message, bytes memory options) = _buildOFTMsgAndOptionsMemory(
            _lzSendParam.sendParam, _lzSendParam.extraOptions, _composeMsg, amountToCreditLD, _srcChainSender
        );

        /// @dev Sends the message to the LayerZero endpoint and returns the LayerZero msg receipt.
        msgReceipt =
            _lzSend(_lzSendParam.sendParam.dstEid, message, options, _lzSendParam.fee, _lzSendParam.refundAddress);
        /// @dev Formulate the OFT receipt.
        oftReceipt = OFTReceipt(amountDebitedLD, amountToCreditLD);

        emit OFTSent(msgReceipt.guid, _lzSendParam.sendParam.dstEid, msg.sender, amountDebitedLD, amountToCreditLD);
    }
    /**
     * @dev For details about this function, check `BaseTapiocaOmnichainEngine._buildOFTMsgAndOptions()`.
     * @dev !!!! IMPORTANT !!!! The differences are:
     *      - memory instead of calldata for parameters.
     *      - `_msgSender` is used instead of using context `msg.sender`, to preserve context of the OFT call and use `msg.sender` of the source chain.
     *      - Does NOT combine options, make sure to pass valid options to cover gas costs/value transfers.
     */

    function _buildOFTMsgAndOptionsMemory(
        SendParam memory _sendParam,
        bytes memory _extraOptions,
        bytes memory _composeMsg,
        uint256 _amountToCreditLD,
        address _msgSender
    ) private view returns (bytes memory message, bytes memory options) {
        bool hasCompose = _composeMsg.length > 0;

        message = hasCompose
            ? abi.encodePacked(
                _sendParam.to, _toSD(_amountToCreditLD), OFTMsgCodec.addressToBytes32(_msgSender), _composeMsg
            )
            : abi.encodePacked(_sendParam.to, _toSD(_amountToCreditLD));
        options = _extraOptions;

        if (msgInspector != address(0)) {
            IOAppMsgInspector(msgInspector).inspect(message, options);
        }
    }
}
