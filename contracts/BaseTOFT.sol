// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {BaseBoringBatchable} from "@boringcrypto/boring-solidity/contracts/BoringBatchable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "tapioca-sdk/dist/contracts/token/oft/v2/OFTV2.sol";
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol";
import "./interfaces/IYieldBox.sol";
import "./lib/TransferLib.sol";
import "./interfaces/ITapiocaWrapper.sol";
import "./interfaces/IMarketHelper.sol";
import "./interfaces/IPermitBorrow.sol";

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
    IYieldBox public yieldBox;
    /// @notice If this wrapper is for an ERC20 or a native token.
    bool public isNative;

    uint16 public constant PT_YB_SEND_STRAT = 770;
    uint16 public constant PT_YB_RETRIEVE_STRAT = 771;
    uint16 public constant PT_YB_DEPOSIT = 772;
    uint16 public constant PT_YB_WITHDRAW = 773;
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
    /// @notice Error while depositing ETH assets to YieldBox.
    error TOFT_YB_ETHDeposit();
    /// @notice Code executed not on main chain.
    error TOFT__NotHostChain();
    /// @notice A zero amount was found
    error TOFT_ZeroAmount();

    // ************** //
    // *** EVENTS *** //
    // ************** //
    event SendApproval(
        address _target,
        address _owner,
        address _spender,
        uint256 _amount
    );
    event YieldBoxDeposit(uint256 _amount);
    event YieldBoxRetrieval(uint256 _amount);
    event Borrow(address indexed _from, uint256 _amount);
    event Wrap(address indexed _from, address indexed _to, uint256 _amount);
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
                "TOFT: Not allowed"
            );
        }
        _;
    }

    constructor(
        address _lzEndpoint,
        bool _isNative,
        IERC20 _erc20,
        IYieldBox _yieldBox,
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
            require(address(_erc20) == address(0), "TOFT__NotNative");
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
    /// @notice Decimal number of the ERC20
    function decimals() public view override returns (uint8) {
        if (_decimalCache == 0) return 18; //temporary fix for LZ _sharedDecimals check
        return _decimalCache;
    }

    /// @notice Check if the current chain is the host chain of the ERC20.
    function isHostChain() external view returns (bool) {
        return block.chainid == hostChainID;
    }

    function getLzChainId() external view returns (uint16) {
        return lzEndpoint.getChainId();
    }

    struct SendOptions {
        uint256 extraGasLimit;
        address zroPaymentAddress;
        bool strategyDeposit;
        bool wrap;
    }
    struct IApproval {
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

    function sendToYB(
        address _from,
        address _to,
        uint256 amount,
        uint256 assetId,
        uint16 lzDstChainId,
        SendOptions calldata options
    ) external payable {
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
            options.strategyDeposit ? PT_YB_SEND_STRAT : PT_YB_DEPOSIT,
            LzLib.addressToBytes32(_from),
            toAddress,
            amount,
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

    function retrieveFromYB(
        address _from,
        uint256 amount,
        uint256 assetId,
        uint16 lzDstChainId,
        address zroPaymentAddress,
        bytes memory airdropAdapterParam,
        bool strategyWithdrawal
    ) external payable {
        bytes32 toAddress = LzLib.addressToBytes32(msg.sender);

        bytes memory lzPayload = abi.encode(
            strategyWithdrawal ? PT_YB_RETRIEVE_STRAT : PT_YB_WITHDRAW,
            LzLib.addressToBytes32(_from),
            toAddress,
            amount,
            0,
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
    /// @notice Estimate the management fees for a wrap operation.
    function _nonblockingLzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64 _nonce,
        bytes memory _payload
    ) internal virtual override {
        uint256 packetType = _payload.toUint256(0); //because we are not using encodePacked

        if (packetType == PT_YB_SEND_STRAT) {
            _ybDeposit(_srcChainId, _payload, IERC20(address(this)), true);
        } else if (packetType == PT_YB_RETRIEVE_STRAT) {
            _ybWithdraw(_srcChainId, _payload, true);
        } else if (packetType == PT_YB_DEPOSIT) {
            _ybDeposit(_srcChainId, _payload, IERC20(address(this)), false);
        } else if (packetType == PT_YB_WITHDRAW) {
            _ybWithdraw(_srcChainId, _payload, false);
        } else if (packetType == PT_YB_SEND_SGL_BORROW) {
            _borrow(_srcChainId, _payload);
        } else {
            packetType = _payload.toUint8(0); //LZ uses encodePacked for payload
            if (packetType == PT_SEND) {
                _sendAck(_srcChainId, _srcAddress, _nonce, _payload);
            } else if (packetType == PT_SEND_AND_CALL) {
                _sendAndCallAck(_srcChainId, _srcAddress, _nonce, _payload);
            } else {
                revert("OFTCoreV2: unknown packet type");
            }
        }
    }

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
            TransferLib.safeTransferETH(_toAddress, _amount);
        } else {
            erc20.safeTransfer(_toAddress, _amount);
        }

        emit Unwrap(msg.sender, _toAddress, _amount);
    }

    function _ybDeposit(
        uint16 _srcChainId,
        bytes memory _payload,
        IERC20 _erc20,
        bool _strategyDeposit
    ) internal virtual {
        (
            ,
            bytes32 fromAddressBytes, //from
            ,
            uint256 amount,
            uint256 assetId
        ) = abi.decode(_payload, (uint16, bytes32, bytes32, uint256, uint256));

        address onBehalfOf = _strategyDeposit
            ? address(this)
            : LzLib.bytes32ToAddress(fromAddressBytes);
        _creditTo(_srcChainId, address(this), amount);
        _depositToYieldbox(assetId, amount, _erc20, address(this), onBehalfOf);

        emit ReceiveFromChain(_srcChainId, onBehalfOf, amount);
    }

    function _ybWithdraw(
        uint16 _srcChainId,
        bytes memory _payload,
        bool _strategyWithdrawal
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
        _retrieveFromYieldBox(
            _assetId,
            _amount,
            _share,
            _strategyWithdrawal ? address(this) : _from,
            address(this)
        );

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
        IMarketHelper(borrowParams.marketHelper).depositAddCollateralAndBorrow{
            value: msg.value
        }(
            borrowParams.market,
            _from,
            borrowParams.amount,
            borrowParams.borrowAmount,
            true,
            true,
            withdrawData
        );

        emit Borrow(_from, borrowParams.amount);
    }

    function _callApproval(IApproval[] memory approvals) internal virtual {
        for (uint256 i = 0; i < approvals.length; ) {
            if (approvals[i].permitBorrow) {
                IPermitBorrow(approvals[i].target).permitBorrow(
                    approvals[i].owner,
                    approvals[i].spender,
                    approvals[i].value,
                    approvals[i].deadline,
                    approvals[i].v,
                    approvals[i].r,
                    approvals[i].s
                );
            } else {
                IERC20Permit(approvals[i].target).permit(
                    approvals[i].owner,
                    approvals[i].spender,
                    approvals[i].value,
                    approvals[i].deadline,
                    approvals[i].v,
                    approvals[i].r,
                    approvals[i].s
                );
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
        IERC20 _erc20,
        address _from,
        address _to
    ) private {
        _erc20.approve(address(yieldBox), _amount);
        yieldBox.depositAsset(_assetId, _from, _to, _amount, 0);

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
}
