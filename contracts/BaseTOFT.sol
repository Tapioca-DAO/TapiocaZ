// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import 'tapioca-sdk/dist/contracts/libraries/LzLib.sol';
import 'tapioca-sdk/dist/contracts/token/oft/OFT.sol';
import './interfaces/IYieldBox.sol';

import './lib/TransferLib.sol';

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
//                      #####
//  %%%%%%%%%%        (####.           *%%%%%%%%%#
//  .%%%%%%%%%%     *####(            .%%%%%%%%%%
//   *%%%%%%%%%%   #####             #%%%%%%%%%%
//               (####.
//      ,((((  ,####(          /(((((((((((((
//        *,  #####  ,(((((((((((((((((((((
//          (####   ((((((((((((((((((((/
//         ####*  (((((((((((((((((((
//                     ,**//*,.

abstract contract BaseTOFT is OFT {
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

    /// @notice Total fees amassed by this contract, in `erc20`.
    uint256 public totalFees;
    /// @notice The ERC20 to wrap.
    IERC20 public erc20;
    /// @notice The host chain ID of the ERC20
    uint256 public hostChainID;
    /// @notice Decimal cache number of the ERC20.
    uint8 internal _decimalCache;

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
    event YieldBoxDeposit(uint256 _amount);
    event YieldBoxRetrieval(uint256 _amount);
    event Wrap(address indexed _from, address indexed _to, uint256 _amount);
    event Unwrap(address indexed _from, address indexed _to, uint256 _amount);
    event HarvestFees(uint256 _amount);

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

    constructor(
        address _lzEndpoint,
        bool _isNative,
        IERC20 _erc20,
        IYieldBox _yieldBox,
        string memory _name,
        string memory _symbol,
        uint8 _decimal,
        uint256 _hostChainID
    )
        OFT(
            string(abi.encodePacked('TapiocaOFT-', _name)),
            string(abi.encodePacked('TOFT-', _symbol)),
            _lzEndpoint
        )
    {
        if (_isNative) {
            require(address(_erc20) == address(0), 'TOFT__NotNative');
        }

        erc20 = _erc20;
        _decimalCache = _decimal;
        hostChainID = _hostChainID;
        isNative = _isNative;
        yieldBox = _yieldBox;
    }

    receive() external payable {}

    // ********************** //
    // *** VIEW FUNCTIONS *** //
    // ********************** //
    /// @notice Decimal number of the ERC20
    function decimals() public view override returns (uint8) {
        return _decimalCache;
    }

    function estimateFees(
        uint256 _feeBps,
        uint256 _feeFraction,
        uint256 _amount
    ) public pure returns (uint256) {
        return (_amount * _feeBps) / _feeFraction;
    }

    /// @notice Check if the current chain is the host chain of the ERC20.
    function isHostChain() external view returns (bool) {
        return block.chainid == hostChainID;
    }

    function getLzChainId() external view returns (uint16) {
        return lzEndpoint.getChainId();
    }

    // ************************ //
    // *** PUBLIC FUNCTIONS *** //
    // ************************ //
    function sendToYB(
        uint256 amount,
        uint256 assetId,
        uint16 lzDstChainId,
        uint256 extraGasLimit,
        address zroPaymentAddress,
        bool strategyDeposit
    ) external payable {
        bytes memory toAddress = abi.encodePacked(msg.sender);
        _debitFrom(msg.sender, lzEndpoint.getChainId(), toAddress, amount);
        bytes memory lzPayload = abi.encode(
            strategyDeposit ? PT_YB_SEND_STRAT : PT_YB_DEPOSIT,
            abi.encodePacked(msg.sender),
            toAddress,
            amount,
            assetId
        );
        bytes memory adapterParam = LzLib.buildDefaultAdapterParams(
            extraGasLimit
        );
        _lzSend(
            lzDstChainId,
            lzPayload,
            payable(msg.sender),
            zroPaymentAddress,
            adapterParam,
            msg.value
        );
        emit SendToChain(lzDstChainId, msg.sender, toAddress, amount);
    }

    function retrieveFromYB(
        uint256 amount,
        uint256 assetId,
        uint16 lzDstChainId,
        address zroPaymentAddress,
        bytes memory airdropAdapterParam,
        bool strategyWithdrawal
    ) external payable {
        bytes memory toAddress = abi.encodePacked(msg.sender);

        bytes memory lzPayload = abi.encode(
            strategyWithdrawal ? PT_YB_RETRIEVE_STRAT : PT_YB_WITHDRAW,
            abi.encodePacked(msg.sender),
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
        uint16 packetType;
        assembly {
            packetType := mload(add(_payload, 32))
        }

        if (packetType == PT_SEND) {
            _sendAck(_srcChainId, _srcAddress, _nonce, _payload);
        } else if (packetType == PT_YB_SEND_STRAT) {
            _ybDeposit(_srcChainId, _payload, IERC20(address(this)), true);
        } else if (packetType == PT_YB_RETRIEVE_STRAT) {
            _ybWithdraw(_srcChainId, _payload, true);
        } else if (packetType == PT_YB_DEPOSIT) {
            _ybDeposit(_srcChainId, _payload, IERC20(address(this)), false);
        } else if (packetType == PT_YB_WITHDRAW) {
            _ybWithdraw(_srcChainId, _payload, false);
        } else {
            revert('OFTCore: unknown packet type');
        }
    }

    function _wrap(
        address _toAddress,
        uint256 _amount,
        uint256 _mngmtFee,
        uint256 _mngmtFeeFraction
    ) internal virtual {
        if (_mngmtFee > 0) {
            uint256 feeAmount = estimateFees(
                _mngmtFee,
                _mngmtFeeFraction,
                _amount
            );

            totalFees += feeAmount;
            erc20.safeTransferFrom(
                msg.sender,
                address(this),
                _amount + feeAmount
            );
        } else {
            erc20.safeTransferFrom(msg.sender, address(this), _amount);
        }

        _mint(_toAddress, _amount);
        emit Wrap(msg.sender, _toAddress, _amount);
    }

    function _wrapNative(
        address _toAddress,
        uint256 _mngmtFee,
        uint256 _mngmtFeeFraction
    ) internal virtual {
        if (msg.value == 0) {
            revert TOFT_ZeroAmount();
        }

        uint256 toMint;

        if (_mngmtFee > 0) {
            uint256 feeAmount = estimateFees(
                _mngmtFee,
                _mngmtFeeFraction,
                msg.value
            );

            totalFees += feeAmount;
            toMint = msg.value - feeAmount;
        }

        _mint(_toAddress, toMint);
        emit Wrap(msg.sender, _toAddress, toMint);
    }

    function _harvestFees(address to) internal virtual {
        erc20.safeTransfer(to, totalFees);
        totalFees = 0;
        emit HarvestFees(totalFees);
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
            //package
            bytes memory fromAddressBytes, //from
            ,
            uint256 amount,
            uint256 assetId
        ) = abi.decode(_payload, (uint16, bytes, bytes, uint256, uint256));

        address onBehalfOf = _strategyDeposit
            ? address(this)
            : fromAddressBytes.toAddress(0);
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
            bytes memory from,
            ,
            uint256 _amount,
            uint256 _share,
            uint256 _assetId,
            address _zroPaymentAddress
        ) = abi.decode(
                _payload,
                (uint16, bytes, bytes, uint256, uint256, uint256, address)
            );

        address _from = from.toAddress(0);
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
            abi.encodePacked(address(this)),
            _amount
        );
        bytes memory lzSendBackPayload = abi.encode(PT_SEND, from, _amount);
        _lzSend(
            _srcChainId,
            lzSendBackPayload,
            payable(this),
            _zroPaymentAddress,
            '',
            address(this).balance
        );
        emit SendToChain(
            _srcChainId,
            _from,
            abi.encodePacked(address(this)),
            _amount
        );

        emit ReceiveFromChain(_srcChainId, _from, _amount);
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
