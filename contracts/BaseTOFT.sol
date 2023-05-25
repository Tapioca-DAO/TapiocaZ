// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseBoringBatchable} from "@boringcrypto/boring-solidity/contracts/BoringBatchable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "tapioca-sdk/dist/contracts/token/oft/v2/OFTV2.sol";
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol";
import "tapioca-periph/contracts/interfaces/IYieldBoxBase.sol";
import "tapioca-periph/contracts/interfaces/ITapiocaWrapper.sol";
import "tapioca-periph/contracts/interfaces/IMagnetar.sol";
import "tapioca-periph/contracts/interfaces/IPermitBorrow.sol";

//
//                 .(%%%%%%%%%%%%*       *
//             #%%%%%%%%%%%%%%%%%%%%*  ####*
//          #%%%%%%%%%%%%%%%%%%%%%#  /####
//       ,%%%%%%%%%%%%%%%%%%%%%%%   ####.  %
//                                #####
//                              #####
//   #####%#####              *####*  ####%#####*
//  (#########(              #####     ##########.
//  ##########             #####.      .##########
//                       ,####/
//                      #####x
//  %%%%%%%%%%        (####.           *%%%%%%%%%#
//  .%%%%%%%%%%     *####(            .%%%%%%%%%%
//   *%%%%%%%%%%   #####             #%%%%%%%%%%
//               (####.
//      ,((((  ,####(          /(((((((((((((
//        *,  #####  ,(((((((((((((((((((((
//          (####   ((((((((((((((((((((/
//         ####*  (((((((((((((((((((
//                     ,**//*,.

abstract contract BaseTOFT is OFTV2, ERC20Permit, BaseBoringBatchable {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    // ************ //
    // *** VARS *** //
    // ************ //
    /// @notice The YieldBox address.
    IYieldBoxBase public yieldBox;
    /// @notice If this wrapper is for an ERC20 or a native token.
    bool public isNative;

    uint16 public constant PT_YB_SEND_STRAT = 770;
    uint16 public constant PT_YB_RETRIEVE_STRAT = 771;
    uint16 public constant PT_YB_SEND_SGL_BORROW = 775;

    /// @notice The ERC20 to wrap.
    IERC20 public erc20;
    /// @notice The host chain ID of the ERC20
    uint256 public hostChainID;
    /// @notice Decimal cache number of the ERC20.
    uint8 internal _decimalCache;

    ITapiocaWrapper private _wrapper;

    // ************** //
    // *** ERRORS *** //
    // ************** //
    /// @notice Code executed not on main chain.
    error TOFT__NotHostChain();
    /// @notice A zero amount was found
    error TOFT_ZeroAmount();

    // ************** //
    // *** EVENTS *** //
    // ************** //
    /// @notice event emitted when approvals are sent
    event SendApproval(
        address _target,
        address _owner,
        address _spender,
        uint256 _amount
    );
    /// @notice event emitted when a YieldBox deposit is done
    event YieldBoxDeposit(uint256 _amount);
    /// @notice event emitted when YieldBox funds are removed
    event YieldBoxRetrieval(uint256 _amount);
    /// @notice event emitted when a borrow operation is performed
    event Borrow(address indexed _from, uint256 _amount);
    /// @notice event emitted when a wrap operation is performed
    event Wrap(address indexed _from, address indexed _to, uint256 _amount);
    /// @notice event emitted when an unwrap operation is performed
    event Unwrap(address indexed _from, address indexed _to, uint256 _amount);

    // ******************//
    // *** MODIFIERS *** //
    // ***************** //
    /// @notice Require that the caller is on the host chain of the ERC20.
    modifier onlyHostChain() {
        if (block.chainid != hostChainID) {
            revert TOFT__NotHostChain();
        }
        _;
    }

    modifier allowed(
        address _owner,
        address _spender,
        uint256 _amount
    ) {
        if (_owner != _spender) {
            require(
                allowance(_owner, _spender) >= _amount,
                "TOFT: not allowed"
            );
        }
        _;
    }

    /// @notice creates a new BaseTOFT contract
    /// @param _lzEndpoint LayerZero endpoint address
    /// @param _isNative true if the underlying ERC20 is actually the chain's native coin
    /// @param _yieldBox the YieldBox address
    /// @param _name the TOFT name
    /// @param _symbol the TOFT symbol
    /// @param _decimal the TOFT decimal
    /// @param _hostChainID the TOFT host chain LayerZero id
    /// @param _tapiocaWrapper the ITapiocaWrapper address
    constructor(
        address _lzEndpoint,
        bool _isNative,
        IERC20 _erc20,
        IYieldBoxBase _yieldBox,
        string memory _name,
        string memory _symbol,
        uint8 _decimal,
        uint256 _hostChainID,
        ITapiocaWrapper _tapiocaWrapper
    )
        OFTV2(
            string(abi.encodePacked("TapiocaOFT-", _name)),
            string(abi.encodePacked("t", _symbol)),
            _decimal / 2,
            _lzEndpoint
        )
        ERC20Permit(string(abi.encodePacked("TapiocaOFT-", _name)))
    {
        if (_isNative) {
            require(address(_erc20) == address(0), "TOFT: not native");
        }

        erc20 = _erc20;
        _decimalCache = _decimal;
        hostChainID = _hostChainID;
        isNative = _isNative;
        yieldBox = _yieldBox;

        _wrapper = _tapiocaWrapper;
    }

    receive() external payable {}

    // ********************** //
    // *** VIEW FUNCTIONS *** //
    // ********************** //
    /// @notice decimal number of the ERC20
    function decimals() public view override returns (uint8) {
        if (_decimalCache == 0) return 18; //temporary fix for LZ _sharedDecimals check
        return _decimalCache;
    }

    /// @notice Check if the current chain is the host chain of the ERC20.
    function isHostChain() external view returns (bool) {
        return block.chainid == hostChainID;
    }

    /// @notice returns current LayerZero chain id
    function getLzChainId() external view returns (uint16) {
        return lzEndpoint.getChainId();
    }

    struct SendOptions {
        uint256 extraGasLimit;
        address zroPaymentAddress;
        bool wrap;
    }
    struct IApproval {
        bool allowFailure;
        address target;
        bool permitBorrow;
        address owner;
        address spender;
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }
    struct IWithdrawParams {
        uint256 withdrawLzFeeAmount;
        bool withdrawOnOtherChain;
        uint16 withdrawLzChainId;
        bytes withdrawAdapterParams;
    }
    struct IBorrowParams {
        uint256 amount;
        uint256 borrowAmount;
        address marketHelper;
        address market;
    }

    // ************************ //
    // *** PUBLIC FUNCTIONS *** //
    // ************************ //
    /// @notice sends TOFT to a specific strategy available on another layer
    /// @param _from the sender address
    /// @param _to the receiver address
    /// @param amount the transferred amount
    /// @param assetId the destination YieldBox asset id
    /// @param lzDstChainId the destination LayerZero id
    /// @param options the operation data
    function sendToStrategy(
        address _from,
        address _to,
        uint256 amount,
        uint256 share,
        uint256 assetId,
        uint16 lzDstChainId,
        SendOptions calldata options
    ) external payable {
        require(amount > 0, "TOFT: amount not valid");
        if (options.wrap) {
            if (isNative) {
                _wrapNative(_to);
            } else {
                _wrap(_from, _to, amount);
            }
        }
        bytes32 toAddress = LzLib.addressToBytes32(_to);
        _debitFrom(_from, lzEndpoint.getChainId(), toAddress, amount);

        bytes memory lzPayload = abi.encode(
            PT_YB_SEND_STRAT,
            LzLib.addressToBytes32(_from),
            toAddress,
            amount,
            share,
            assetId
        );

        bytes memory adapterParam = LzLib.buildDefaultAdapterParams(
            options.extraGasLimit
        );
        _lzSend(
            lzDstChainId,
            lzPayload,
            payable(_from),
            options.zroPaymentAddress,
            adapterParam,
            msg.value
        );

        emit SendToChain(lzDstChainId, _from, toAddress, amount);
    }

    /// @notice sends TOFT to a specific chain and performs a borrow operation
    /// @param _from the sender address
    /// @param _to the receiver address
    /// @param lzDstChainId the destination LayerZero id
    /// @param airdropAdapterParams the LayerZero aidrop adapter params
    /// @param borrowParams the borrow operation data
    /// @param withdrawParams the withdraw operation data
    /// @param options the cross chain send operation data
    /// @param approvals the cross chain approval operation data
    function sendToYBAndBorrow(
        address _from,
        address _to,
        uint16 lzDstChainId,
        bytes calldata airdropAdapterParams,
        IBorrowParams calldata borrowParams,
        IWithdrawParams calldata withdrawParams,
        SendOptions calldata options,
        IApproval[] calldata approvals
    ) external payable {
        if (options.wrap) {
            if (isNative) {
                _wrapNative(_to);
            } else {
                _wrap(_from, _to, borrowParams.amount);
            }
        }
        bytes32 toAddress = LzLib.addressToBytes32(_to);
        _debitFrom(
            _from,
            lzEndpoint.getChainId(),
            toAddress,
            borrowParams.amount
        );

        bytes memory lzPayload = abi.encode(
            PT_YB_SEND_SGL_BORROW,
            _from,
            toAddress,
            borrowParams,
            withdrawParams,
            approvals
        );

        _lzSend(
            lzDstChainId,
            lzPayload,
            payable(_from),
            options.zroPaymentAddress,
            airdropAdapterParams,
            msg.value
        );

        emit SendToChain(lzDstChainId, _from, toAddress, borrowParams.amount);
    }

    /// @notice extracts TOFT from a specific strategy available on another layer
    /// @param _from the sender address
    /// @param amount the transferred amount
    /// @param assetId the destination YieldBox asset id
    /// @param lzDstChainId the destination LayerZero id
    /// @param zroPaymentAddress LayerZero ZRO payment address
    /// @param airdropAdapterParam the LayerZero aidrop adapter params
    function retrieveFromStrategy(
        address _from,
        uint256 amount,
        uint256 share,
        uint256 assetId,
        uint16 lzDstChainId,
        address zroPaymentAddress,
        bytes memory airdropAdapterParam
    ) external payable {
        require(amount > 0, "TOFT: amount not valid");

        bytes32 toAddress = LzLib.addressToBytes32(msg.sender);

        bytes memory lzPayload = abi.encode(
            PT_YB_RETRIEVE_STRAT,
            LzLib.addressToBytes32(_from),
            toAddress,
            amount,
            share,
            assetId,
            zroPaymentAddress
        );
        _lzSend(
            lzDstChainId,
            lzPayload,
            payable(msg.sender),
            zroPaymentAddress,
            airdropAdapterParam,
            msg.value
        );
        emit SendToChain(lzDstChainId, msg.sender, toAddress, amount);
    }

    // ************************* //
    // *** PRIVATE FUNCTIONS *** //
    // ************************* //
    function _wrap(
        address _fromAddress,
        address _toAddress,
        uint256 _amount
    ) internal virtual allowed(_fromAddress, msg.sender, _amount) {
        erc20.safeTransferFrom(_fromAddress, address(this), _amount);
        _mint(_toAddress, _amount);
        emit Wrap(_fromAddress, _toAddress, _amount);
    }

    function _wrapNative(address _toAddress) internal virtual {
        if (msg.value == 0) {
            revert TOFT_ZeroAmount();
        }

        _mint(_toAddress, msg.value);
        emit Wrap(msg.sender, _toAddress, msg.value);
    }

    function _unwrap(address _toAddress, uint256 _amount) internal virtual {
        _burn(msg.sender, _amount);

        if (isNative) {
            _safeTransferETH(_toAddress, _amount);
        } else {
            erc20.safeTransfer(_toAddress, _amount);
        }

        emit Unwrap(msg.sender, _toAddress, _amount);
    }

    function _strategyDeposit(
        uint16 _srcChainId,
        bytes memory _payload,
        IERC20 _erc20
    ) internal virtual {
        (, , bytes32 from, uint256 amount, uint256 share, uint256 assetId) = abi
            .decode(
                _payload,
                (uint16, bytes32, bytes32, uint256, uint256, uint256)
            );

        address onBehalfOf = LzLib.bytes32ToAddress(from);

        _creditTo(_srcChainId, address(this), amount);
        _depositToYieldbox(
            assetId,
            amount,
            share,
            _erc20,
            address(this),
            onBehalfOf
        );

        emit ReceiveFromChain(_srcChainId, onBehalfOf, amount);
    }

    function _strategyWithdraw(
        uint16 _srcChainId,
        bytes memory _payload
    ) internal virtual {
        (
            ,
            bytes32 from,
            ,
            uint256 _amount,
            uint256 _share,
            uint256 _assetId,
            address _zroPaymentAddress
        ) = abi.decode(
                _payload,
                (uint16, bytes32, bytes32, uint256, uint256, uint256, address)
            );

        address _from = LzLib.bytes32ToAddress(from);
        _retrieveFromYieldBox(_assetId, _amount, _share, _from, address(this));

        _debitFrom(
            address(this),
            lzEndpoint.getChainId(),
            LzLib.addressToBytes32(address(this)),
            _amount
        );

        bytes memory lzSendBackPayload = _encodeSendPayload(
            from,
            _ld2sd(_amount)
        );
        _lzSend(
            _srcChainId,
            lzSendBackPayload,
            payable(this),
            _zroPaymentAddress,
            "",
            address(this).balance
        );
        emit SendToChain(
            _srcChainId,
            _from,
            LzLib.addressToBytes32(address(this)),
            _amount
        );

        emit ReceiveFromChain(_srcChainId, _from, _amount);
    }

    /// @notice Deposit to this address, then use MarketHelper to deposit and add collateral, borrow and withdrawTo
    /// @dev Payload format: (uint16 packetType, bytes32 fromAddressBytes, bytes32 nonces, uint256 amount, uint256 borrowAmount, address MarketHelper, address Market)
    /// @param _srcChainId The chain id of the source chain
    /// @param _payload The payload of the packet
    function _borrow(
        uint16 _srcChainId,
        bytes memory _payload
    ) internal virtual {
        (
            ,
            address _from, //from
            ,
            IBorrowParams memory borrowParams,
            IWithdrawParams memory withdrawParams,
            IApproval[] memory approvals
        ) = abi.decode(
                _payload,
                (
                    uint16,
                    address,
                    bytes32,
                    IBorrowParams,
                    IWithdrawParams,
                    IApproval[]
                )
            );

        if (approvals.length > 0) {
            _callApproval(approvals);
        }
        _creditTo(_srcChainId, address(this), borrowParams.amount);

        // Use market helper to deposit, add collateral to market and withdrawTo
        bytes memory withdrawData = abi.encode(
            withdrawParams.withdrawOnOtherChain,
            withdrawParams.withdrawLzChainId,
            _from,
            withdrawParams.withdrawAdapterParams
        );
        approve(address(borrowParams.marketHelper), borrowParams.amount);
        IMagnetar(borrowParams.marketHelper).depositAddCollateralAndBorrow{
            value: msg.value
        }(
            borrowParams.market,
            _from,
            borrowParams.amount,
            borrowParams.borrowAmount,
            true,
            true,
            true,
            withdrawData
        );

        emit Borrow(_from, borrowParams.amount);
    }

    function _callApproval(IApproval[] memory approvals) internal virtual {
        for (uint256 i = 0; i < approvals.length; ) {
            if (approvals[i].permitBorrow) {
                try
                    IPermitBorrow(approvals[i].target).permitBorrow(
                        approvals[i].owner,
                        approvals[i].spender,
                        approvals[i].value,
                        approvals[i].deadline,
                        approvals[i].v,
                        approvals[i].r,
                        approvals[i].s
                    )
                {} catch Error(string memory reason) {
                    if (!approvals[i].allowFailure) {
                        revert(reason);
                    }
                }
            } else {
                try
                    IERC20Permit(approvals[i].target).permit(
                        approvals[i].owner,
                        approvals[i].spender,
                        approvals[i].value,
                        approvals[i].deadline,
                        approvals[i].v,
                        approvals[i].r,
                        approvals[i].s
                    )
                {} catch Error(string memory reason) {
                    if (!approvals[i].allowFailure) {
                        revert(reason);
                    }
                }
            }

            unchecked {
                ++i;
            }
        }
    }

    /// @notice Receive an inter-chain transaction to execute a deposit inside YieldBox.
    function _depositToYieldbox(
        uint256 _assetId,
        uint256 _amount,
        uint256 _share,
        IERC20 _erc20,
        address _from,
        address _to
    ) private {
        if (_share > 0) {
            //share takes precedance over amount
            _amount = yieldBox.toAmount(_assetId, _share, false);
        }
        _erc20.approve(address(yieldBox), _amount);
        yieldBox.depositAsset(_assetId, _from, _to, _amount, _share);

        emit YieldBoxDeposit(_amount);
    }

    /// @notice Receive an inter-chain transaction to execute a deposit inside YieldBox.
    function _retrieveFromYieldBox(
        uint256 _assetId,
        uint256 _amount,
        uint256 _share,
        address _from,
        address _to
    ) private {
        yieldBox.withdraw(_assetId, _from, _to, _amount, _share);

        emit YieldBoxRetrieval(_amount);
    }

    function _safeTransferETH(address to, uint256 amount) internal {
        bool success;

        assembly {
            // Transfer the ETH and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(success, "TOFT: transfer failed (ETH)");
    }

    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) internal virtual override {
        uint256 packetType = _payload.toUint256(0);

        if (packetType == PT_YB_SEND_STRAT) {
            _strategyDeposit(_srcChainId, _payload, IERC20(address(this)));
        } else if (packetType == PT_YB_RETRIEVE_STRAT) {
            _strategyWithdraw(_srcChainId, _payload);
        } else if (packetType == PT_YB_SEND_SGL_BORROW) {
            _borrow(_srcChainId, _payload);
        } else {
            packetType = _payload.toUint8(0);
            if (packetType == PT_SEND) {
                _sendAck(_srcChainId, _srcAddress, _nonce, _payload);
            } else if (packetType == PT_SEND_AND_CALL) {
                _sendAndCallAck(_srcChainId, _srcAddress, _nonce, _payload);
            } else {
                revert("OFTCoreV2: unknown packet type");
            }
        }
    }
}
