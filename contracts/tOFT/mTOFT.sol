// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

//LZ
import {IMessagingChannel} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/IMessagingChannel.sol";
import {MessagingReceipt, OFTReceipt} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oft/interfaces/IOFT.sol";
import {OAppReceiver} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OAppReceiver.sol";
import {Origin} from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";

// External
import {ERC20Permit, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

// Tapioca
import {
    ITOFT,
    TOFTInitStruct,
    TOFTModulesInitStruct,
    LZSendParam,
    ERC20PermitStruct,
    IToftVault
} from "tapioca-periph/interfaces/oft/ITOFT.sol";
import {BaseTapiocaOmnichainEngine} from "tapioca-periph/tapiocaOmnichainEngine/BaseTapiocaOmnichainEngine.sol";
import {TapiocaOmnichainSender} from "tapioca-periph/tapiocaOmnichainEngine/TapiocaOmnichainSender.sol";
import {IStargateReceiver} from "tapioca-periph/interfaces/external/stargate/IStargateReceiver.sol";
import {TOFTReceiver} from "./modules/TOFTReceiver.sol";
import {TOFTSender} from "./modules/TOFTSender.sol";
import {BaseTOFT} from "./BaseTOFT.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

/**
 * @title mTOFT
 * @author TapiocaDAO
 * @notice Tapioca OFT wrapper contract that is connected with multiple chains
 * @dev It can be wrapped and unwrapped on multiple connected chains
 */
contract mTOFT is BaseTOFT, Pausable, ReentrancyGuard, ERC20Permit, IStargateReceiver {
    using SafeERC20 for IERC20;

    /**
     * @notice allowed chains where you can unwrap your TOFT
     */
    mapping(uint256 => bool) public connectedChains;

    /**
     * @notice map of approved balancers
     * @dev a balancer can extract the underlying
     */
    mapping(address => bool) public balancers;

    /**
     * @notice max mTOFT mintable
     */
    uint256 public mintCap;

    /**
     * @notice current non-host chain mint fee
     */
    uint256 public mintFee;

    address private _stargateRouter;

    event StargateRouterUpdated(address indexed _old, address indexed _new);

    /**
     * @notice event emitted when a connected chain is reigstered or unregistered
     */
    event ConnectedChainStatusUpdated(uint256 indexed _chain, bool indexed _old, bool indexed _new);

    /**
     * @notice event emitted when balancer status is updated
     */
    event BalancerStatusUpdated(address indexed _balancer, bool indexed _bool, bool indexed _new);

    /**
     * @notice event emitted when rebalancing is performed
     */
    event Rebalancing(address indexed _balancer, uint256 indexed _amount, bool indexed _isNative);

    error mTOFT_NotNative();
    error mTOFT_NotHost();
    error mTOFT_BalancerNotAuthorized();
    error mTOFT_NotAuthorized();
    error mTOFT_CapNotValid();
    error mTOFT_Failed();

    constructor(TOFTInitStruct memory _tOFTData, TOFTModulesInitStruct memory _modulesData, address _stgRouter)
        BaseTOFT(_tOFTData)
        ERC20Permit(_tOFTData.name)
    {
        if (_getChainId() == hostEid) {
            connectedChains[hostEid] = true;
        }

        mintCap = 1_000_000 * 1e18; // TOFT is always in 18 decimals
        mintFee = 5e2; // 0.5%

        // Set TOFT execution modules
        if (_modulesData.tOFTSenderModule == address(0)) revert TOFT_NotValid();
        if (_modulesData.tOFTReceiverModule == address(0)) {
            revert TOFT_NotValid();
        }
        if (_modulesData.marketReceiverModule == address(0)) {
            revert TOFT_NotValid();
        }
        if (_modulesData.optionsReceiverModule == address(0)) {
            revert TOFT_NotValid();
        }
        if (_modulesData.genericReceiverModule == address(0)) {
            revert TOFT_NotValid();
        }

        _setModule(uint8(ITOFT.Module.TOFTSender), _modulesData.tOFTSenderModule);
        _setModule(uint8(ITOFT.Module.TOFTReceiver), _modulesData.tOFTReceiverModule);
        _setModule(uint8(ITOFT.Module.TOFTMarketReceiver), _modulesData.marketReceiverModule);
        _setModule(uint8(ITOFT.Module.TOFTOptionsReceiver), _modulesData.optionsReceiverModule);
        _setModule(uint8(ITOFT.Module.TOFTGenericReceiver), _modulesData.genericReceiverModule);

        _stargateRouter = _stgRouter;

        vault = IToftVault(_tOFTData.vault);
        vault.claimOwnership();

        if (address(vault._token()) != erc20) revert TOFT_VaultWrongERC20();
    }

    /**
     * @dev Fallback function should handle calls made by endpoint, which should go to the receiver module.
     */
    fallback() external payable {
        /// @dev Call the receiver module on fallback, assume it's gonna be called by endpoint.
        _executeModule(uint8(ITOFT.Module.TOFTReceiver), msg.data, false);
    }

    receive() external payable {}

    function transferFrom(address from, address to, uint256 value)
        public
        override(BaseTapiocaOmnichainEngine, ERC20)
        returns (bool)
    {
        return BaseTapiocaOmnichainEngine.transferFrom(from, to, value);
    }

    /**
     * @dev Slightly modified version of the OFT _lzReceive() operation.
     * The composed message is sent to `address(this)` instead of `toAddress`.
     * @dev Internal function to handle the receive on the LayerZero endpoint.
     * @param _origin The origin information.
     *  - srcEid: The source chain endpoint ID.
     *  - sender: The sender address from the src chain.
     *  - nonce: The nonce of the LayerZero message.
     * @param _guid The unique identifier for the received LayerZero message.
     * @param _message The encoded message.
     * @dev _executor The address of the executor.
     * @dev _extraData Additional data.
     */
    function lzReceive(
        Origin calldata _origin,
        bytes32 _guid,
        bytes calldata _message,
        address _executor, // @dev unused in the default implementation.
        bytes calldata _extraData // @dev unused in the default implementation.
    ) public payable override {
        // Call the internal OApp implementation of lzReceive.
        _executeModule(
            uint8(ITOFT.Module.TOFTReceiver),
            abi.encodeWithSelector(OAppReceiver.lzReceive.selector, _origin, _guid, _message, _executor, _extraData),
            false
        );
    }

    /**
     * @notice Execute a call to a module.
     * @dev Example on how `_data` should be encoded:
     *      - abi.encodeCall(IERC20.transfer, (to, amount));
     * @dev Use abi.encodeCall to encode the function call and its parameters with type safety.
     *
     * @param _module The module to execute.
     * @param _data The data to execute. Should be ABI encoded with the selector.
     * @param _forwardRevert If true, forward the revert message from the module.
     *
     * @return returnData The return data from the module execution, if any.
     */
    function executeModule(ITOFT.Module _module, bytes memory _data, bool _forwardRevert)
        external
        payable
        whenNotPaused
        returns (bytes memory returnData)
    {
        return _executeModule(uint8(_module), _data, _forwardRevert);
    }

    /**
     * @dev Slightly modified version of the OFT send() operation. Includes a `_msgType` parameter.
     * The `_buildMsgAndOptionsByType()` appends the packet type to the message.
     * @dev Executes the send operation.
     * @param _lzSendParam The parameters for the send operation.
     *      - _sendParam: The parameters for the send operation.
     *          - dstEid::uint32: Destination endpoint ID.
     *          - to::bytes32: Recipient address.
     *          - amountToSendLD::uint256: Amount to send in local decimals.
     *          - minAmountToCreditLD::uint256: Minimum amount to credit in local decimals.
     *      - _fee: The calculated fee for the send() operation.
     *          - nativeFee::uint256: The native fee.
     *          - lzTokenFee::uint256: The lzToken fee.
     *      - _extraOptions::bytes: Additional options for the send() operation.
     *      - refundAddress::address: The address to refund the native fee to.
     * @param _composeMsg The composed message for the send() operation. Is a combination of 1 or more TAP specific messages.
     *
     * @return msgReceipt The receipt for the send operation.
     *      - guid::bytes32: The unique identifier for the sent message.
     *      - nonce::uint64: The nonce of the sent message.
     *      - fee: The LayerZero fee incurred for the message.
     *          - nativeFee::uint256: The native fee.
     *          - lzTokenFee::uint256: The lzToken fee.
     * @return oftReceipt The OFT receipt information.
     *      - amountDebitLD::uint256: Amount of tokens ACTUALLY debited in local decimals.
     *      - amountCreditLD::uint256: Amount of tokens to be credited on the remote side.
     */
    function sendPacket(LZSendParam calldata _lzSendParam, bytes calldata _composeMsg)
        public
        payable
        whenNotPaused
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt)
    {
        (msgReceipt, oftReceipt) = abi.decode(
            _executeModule(
                uint8(ITOFT.Module.TOFTSender),
                abi.encodeCall(TapiocaOmnichainSender.sendPacket, (_lzSendParam, _composeMsg)),
                false
            ),
            (MessagingReceipt, OFTReceipt)
        );
    }

    /// =====================
    /// View
    /// =====================

    /**
     * @dev Returns the hash of the struct used by the permit function.
     * @param _permitData Struct containing permit data.
     */
    function getTypedDataHash(ERC20PermitStruct calldata _permitData) public view returns (bytes32) {
        bytes32 permitTypeHash_ =
            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

        bytes32 structHash_ = keccak256(
            abi.encode(
                permitTypeHash_,
                _permitData.owner,
                _permitData.spender,
                _permitData.value,
                _permitData.nonce,
                _permitData.deadline
            )
        );
        return _hashTypedDataV4(structHash_);
    }

    /// =====================
    /// External
    /// =====================
    /**
     * @notice Wrap an ERC20 with a fee if existing.
     * @dev Minted amount might be less than requested amount. see `mintFee`
     * @param _fromAddress The address to wrap from.
     * @param _toAddress The address to wrap the ERC20 to.
     * @param _amount The amount of ERC20 to wrap.
     *
     * @return minted The mtOFT minted amount.
     */
    function wrap(address _fromAddress, address _toAddress, uint256 _amount)
        external
        payable
        whenNotPaused
        nonReentrant
        returns (uint256 minted)
    {
        if (balancers[msg.sender]) revert mTOFT_BalancerNotAuthorized();
        if (!connectedChains[_getChainId()]) revert mTOFT_NotHost();
        if (mintCap > 0) {
            if (totalSupply() + _amount > mintCap) revert mTOFT_CapNotValid();
        }

        uint256 feeAmount = _checkAndExtractFees(_amount);
        if (erc20 == address(0)) {
            _wrapNative(_toAddress, _amount, feeAmount);
        } else {
            if (msg.value > 0) revert mTOFT_NotNative();
            _wrap(_fromAddress, _toAddress, _amount, feeAmount);
        }

        return _amount - feeAmount;
    }

    /**
     * @notice Unwrap an ERC20/Native with a 1:1 ratio.
     * @param _toAddress The address to wrap the ERC20 to.
     * @param _amount The amount of tokens to unwrap.
     */
    function unwrap(address _toAddress, uint256 _amount) external nonReentrant whenNotPaused {
        if (!connectedChains[_getChainId()]) revert mTOFT_NotHost();
        if (balancers[msg.sender]) revert mTOFT_BalancerNotAuthorized();
        _unwrap(_toAddress, _amount);
    }

    /**
     * @notice needed for Stargate Router to receive funds from Balancer.sol contract
     * @param amountLD Amount to deposit
     */
    function sgReceive(uint16, bytes memory, uint256, address, uint256 amountLD, bytes memory) external payable {
        if (msg.sender != _stargateRouter) revert mTOFT_NotAuthorized();

        if (erc20 == address(0)) {
            vault.depositNative{value: amountLD}();
        } else {
            IERC20(erc20).safeTransfer(address(vault), amountLD);
        }
    }

    /// =====================
    /// Owner
    /// =====================
    /**
     * @notice rescues unused ETH from the contract
     * @param amount the amount to rescue
     * @param to the recipient
     */
    function rescueEth(uint256 amount, address to) external onlyOwner {
        (bool success,) = to.call{value: amount}("");
        if (!success) revert mTOFT_Failed();
    }

    /**
     * @notice sets the owner state
     */
    struct SetOwnerStateData {
        address stargateRouter;
        uint256 mintFee;
        uint256 mintCap;
        // connected chains
        uint256 connectedChain;
        bool connectedChainState;
        // balancer
        address balancerStateAddress;
        bool balancerState;
    }

    function setOwnerState(SetOwnerStateData memory _data) external onlyOwner {
        if (_stargateRouter != _data.stargateRouter) {
            _stargateRouter = _data.stargateRouter;
        }
        if (mintFee != _data.mintFee) {
            mintFee = _data.mintFee;
        }
        if (mintCap != _data.mintCap) {
            if (_data.mintCap < totalSupply()) revert mTOFT_CapNotValid();
            mintCap = _data.mintCap;
        }
        if (connectedChains[_data.connectedChain] != _data.connectedChainState) {
            connectedChains[_data.connectedChain] = _data.connectedChainState;
        }
        if (balancers[_data.balancerStateAddress] != _data.balancerState) {
            balancers[_data.balancerStateAddress] = _data.balancerState;
        }
    }

    /**
     * @notice withdraw fees from Vault.
     * @param _to receiver; usually Balancer.sol contract
     * @param _amount the fees amount
     */
    function withdrawFees(address _to, uint256 _amount) external onlyOwner {
        vault.transferFees(_to, _amount);
    }

    /**
     * @notice extracts the underlying token/native for rebalancing
     * @param _amount the amount used for rebalancing
     */
    function extractUnderlying(uint256 _amount) external nonReentrant {
        if (!balancers[msg.sender]) revert mTOFT_BalancerNotAuthorized();
        if (_amount == 0) revert TOFT_NotValid();

        vault.withdraw(msg.sender, _amount);

        emit Rebalancing(msg.sender, _amount, erc20 == address(0));
    }

    /// =====================
    /// Private
    /// =====================
    function _checkAndExtractFees(uint256 _amount) private returns (uint256 feeAmount) {
        feeAmount = 0;

        // not on host chain; extract fee
        // fees are used to rebalance liquidity to host chain
        if (_getChainId() != hostEid && mintFee > 0) {
            feeAmount = (_amount * mintFee) / 1e5;
            if (feeAmount > 0) {
                if (erc20 == address(0)) {
                    vault.registerFees{value: feeAmount}(feeAmount);
                } else {
                    vault.registerFees(feeAmount);
                }
            }
        }
    }
    /**
     * @notice Return the current chain EID.
     */

    function _getChainId() internal view override returns (uint32) {
        return IMessagingChannel(endpoint).eid();
    }
}
