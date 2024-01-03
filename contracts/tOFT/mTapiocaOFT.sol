// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./BaseTOFT.sol";

contract mTapiocaOFT is BaseTOFT, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ************ //
    // *** VARS *** //
    // ************ //

    /// @notice allowed chains where you can unwrap your TOFT
    mapping(uint256 => bool) public connectedChains;

    /// @notice map of approved balancers
    /// @dev a balancer can extract the underlying
    mapping(address => bool) public balancers;

    // ************** //
    // *** EVENTS *** //
    // ************** //
    /// @notice event emitted when a connected chain is reigstered or unregistered
    event ConnectedChainStatusUpdated(
        uint256 indexed _chain,
        bool indexed _old,
        bool indexed _new
    );
    /// @notice event emitted when balancer status is updated
    event BalancerStatusUpdated(
        address indexed _balancer,
        bool indexed _bool,
        bool indexed _new
    );
    /// @notice event emitted when rebalancing is performed
    event Rebalancing(
        address indexed _balancer,
        uint256 indexed _amount,
        bool indexed _isNative
    );

    // ************** //
    // *** ERRORS *** //
    // ************** //
    error NotHost();
    error BalancerNotAuthorized();

    /// @notice creates a new mTapiocaOFT
    /// @param _lzEndpoint LayerZero endpoint address
    /// @param _erc20 true the underlying ERC20 address
    /// @param _yieldBox the YieldBox address
    /// @param _name the TOFT name
    /// @param _symbol the TOFT symbol
    /// @param _decimal the TOFT decimal
    /// @param _hostChainID the TOFT host chain LayerZero id
    constructor(
        address _lzEndpoint,
        address _erc20,
        IYieldBoxBase _yieldBox,
        ICluster _cluster,
        string memory _name,
        string memory _symbol,
        uint8 _decimal,
        uint256 _hostChainID,
        BaseTOFTLeverageModule __leverageModule,
        BaseTOFTLeverageDestinationModule __leverageDestinationModule,
        BaseTOFTMarketModule __marketModule,
        BaseTOFTMarketDestinationModule __marketDestinationModule,
        BaseTOFTOptionsModule __optionsModule,
        BaseTOFTOptionsDestinationModule __optionsDestinationModule,
        BaseTOFTGenericModule __genericModule
    )
        BaseTOFT(
            _lzEndpoint,
            _erc20,
            _yieldBox,
            _cluster,
            _name,
            _symbol,
            _decimal,
            _hostChainID,
            __leverageModule,
            __leverageDestinationModule,
            __marketModule,
            __marketDestinationModule,
            __optionsModule,
            __optionsDestinationModule,
            __genericModule
        )
    {
        if (block.chainid == _hostChainID) {
            connectedChains[_hostChainID] = true;
        }
    }

    // ************************ //
    // *** PUBLIC FUNCTIONS *** //
    // ************************ //
    /// @notice Wrap an ERC20 with a 1:1 ratio with a fee if existing.
    /// @dev Since it can be executed only on the main chain, if an address exists on the OP chain it will not allowed to wrap.
    /// @param _toAddress The address to wrap the ERC20 to.
    /// @param _amount The amount of ERC20 to wrap.
    function wrap(
        address _fromAddress,
        address _toAddress,
        uint256 _amount
    ) external payable onlyHostChain {
        if (balancers[msg.sender]) revert BalancerNotAuthorized();
        if (erc20 == address(0)) {
            _wrapNative(_toAddress);
        } else {
            if (msg.value > 0) revert NotNative();
            _wrap(_fromAddress, _toAddress, _amount);
        }
    }

    /// @notice Unwrap an ERC20/Native with a 1:1 ratio. Called only on host chain.
    /// @param _toAddress The address to unwrap the tokens to.
    /// @param _amount The amount of tokens to unwrap.
    function unwrap(address _toAddress, uint256 _amount) external {
        if (!connectedChains[block.chainid]) revert NotHost();
        if (balancers[msg.sender]) revert BalancerNotAuthorized();
        _unwrap(_toAddress, _amount);
    }

    // *********************** //
    // *** OWNER FUNCTIONS *** //
    // *********************** //
    /// @notice updates a connected chain whitelist status
    /// @param _chain the block.chainid of that specific chain
    /// @param _status the new whitelist status
    function updateConnectedChain(
        uint256 _chain,
        bool _status
    ) external onlyOwner {
        emit ConnectedChainStatusUpdated(
            _chain,
            connectedChains[_chain],
            _status
        );
        connectedChains[_chain] = _status;
    }

    /// @notice updates a Balancer whitelist status
    /// @param _balancer the operator address
    /// @param _status the new whitelist status
    function updateBalancerState(
        address _balancer,
        bool _status
    ) external onlyOwner {
        emit BalancerStatusUpdated(_balancer, balancers[_balancer], _status);
        balancers[_balancer] = _status;
    }

    /// @notice extracts the underlying token/native for rebalancing
    /// @param _amount the amount used for rebalancing
    function extractUnderlying(uint256 _amount) external nonReentrant {
        if (!balancers[msg.sender]) revert BalancerNotAuthorized();
        if (_amount == 0) revert NotValid();

        bool _isNative = erc20 == address(0);
        vault.withdraw(msg.sender, _amount);

        emit Rebalancing(msg.sender, _amount, _isNative);
    }
}
