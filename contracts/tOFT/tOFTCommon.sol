// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

//OFT imports
import "tapioca-sdk/dist/contracts/token/oft/v2/OFTV2.sol";
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol";

//OZ imports
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

//Interfaces
import "tapioca-periph/contracts/interfaces/IYieldBoxBase.sol";
import "tapioca-periph/contracts/interfaces/ITapiocaWrapper.sol";


abstract contract tOFTCommon is ERC20Permit {
    using SafeERC20 for IERC20;

    // ************ //
    // *** VARS *** //
    // ************ //
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

    uint16 public constant PT_YB_SEND_STRAT = 770;
    uint16 public constant PT_YB_RETRIEVE_STRAT = 771;
    uint16 public constant PT_YB_SEND_SGL_BORROW = 775;


    IYieldBoxBase public yieldBox;
    /// @notice If this wrapper is for an ERC20 or a native token.
    bool public isNative;


    /// @notice The ERC20 to wrap.
    IERC20 public erc20;
    /// @notice The host chain ID of the ERC20
    uint256 public hostChainID;
    /// @notice Decimal cache number of the ERC20.
    uint8 internal _decimalCache;

    struct SendOptions {
        uint256 extraGasLimit;
        address zroPaymentAddress;
        bool wrap;
    }

    // ************** //
    // *** EVENTS *** //
    // ************** //
    /// @notice event emitted when a YieldBox deposit is done
    event YieldBoxDeposit(uint256 _amount);
    /// @notice event emitted when YieldBox funds are removed
    event YieldBoxRetrieval(uint256 _amount);

     // ******************//
    // *** MODIFIERS *** //
    // ***************** //
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

    receive() external payable {}
    constructor(
        string memory _name,
        string memory _symbol
    ) 
        ERC20Permit(string(abi.encodePacked("TapiocaOFT-", _name)))
    {
    }
    
    // ********************** //
    // *** VIEW FUNCTIONS *** //
    // ********************** //
    /// @notice Check if the current chain is the host chain of the ERC20.
    function isHostChain() external view returns (bool) {
        return block.chainid == hostChainID;
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
    }

    function _wrapNative(address _toAddress) internal virtual {
        require(msg.value > 0, "TOFT: not zero");
        _mint(_toAddress, msg.value);
    }

    function _unwrap(address _toAddress, uint256 _amount) internal virtual {
        _burn(msg.sender, _amount);

        if (isNative) {
            _safeTransferETH(_toAddress, _amount);
        } else {
            erc20.safeTransfer(_toAddress, _amount);
        }

    }

    function _safeTransferETH(address to, uint256 amount) internal {
        bool success;

        assembly {
            // Transfer the ETH and store if it succeeded or not.
            success := call(gas(), to, amount, 0, 0, 0, 0)
        }

        require(success, "TOFT: transfer failed (ETH)");
    }

    /// @notice Receive an inter-chain transaction to execute a deposit inside YieldBox.
    function _depositToYieldbox(
        uint256 _assetId,
        uint256 _amount,
        uint256 _share,
        IERC20 _erc20,
        address _from,
        address _to
    ) internal {
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
    ) internal {
        yieldBox.withdraw(_assetId, _from, _to, _amount, _share);

        emit YieldBoxRetrieval(_amount);
    }
}