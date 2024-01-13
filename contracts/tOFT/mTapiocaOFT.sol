// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

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

    /// @notice max mTOFT mintable
    uint256 public mintCap;

    /// @notice current non-host chain mint fee
    uint256 public mintFee;

    uint256 private constant _FEE_PRECISION = 1e5;

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
    /// @notice event emitted when mint cap is updated
    event MintCapUpdated(uint256 indexed oldVal, uint256 indexed newVal);

    /// @notice event emitted when mint fee is updated
    event MintFeeUpdated(uint256 indexed oldVal, uint256 indexed newVal);

    // ************** //
    // *** ERRORS *** //
    // ************** //
    error NotHost();
    error BalancerNotAuthorized();
    error CapNotValid();
    error OverCap();

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

        hostChainID = _hostChainID;
        mintCap = 1_000_000 * 1e18; // TOFT is always in 18 decimals
        mintFee = 5e2; // 0.5%
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
    ) external payable nonReentrant returns (uint256 minted) {
        if (balancers[msg.sender]) revert BalancerNotAuthorized();
        if (!connectedChains[block.chainid]) revert NotHost();
        if (totalSupply() + _amount > mintCap) revert OverCap();

        uint256 feeAmount = _checkAndExtractFees(_amount);

        if (erc20 == address(0)) {
            _wrapNative(_toAddress, _amount, feeAmount);
        } else {
            if (msg.value > 0) revert NotNative();
            _wrap(_fromAddress, _toAddress, _amount, feeAmount);
        }

        return _amount - feeAmount;
    }

    /// @notice Unwrap an ERC20/Native with a 1:1 ratio. Called only on host chain.
    /// @param _toAddress The address to unwrap the tokens to.
    /// @param _amount The amount of tokens to unwrap.
    function unwrap(address _toAddress, uint256 _amount) external nonReentrant {
        if (!connectedChains[block.chainid]) revert NotHost();
        if (balancers[msg.sender]) revert BalancerNotAuthorized();
        _unwrap(_toAddress, _amount);
    }

    // *********************** //
    // *** OWNER FUNCTIONS *** //
    // *********************** //
    /// @notice withdraw fees from Vault
    /// @param to receiver; usually Balancer.sol contract
    /// @param amount the fees amount
    function withdrawFees(address to, uint256 amount) external onlyOwner {
        vault.transferFees(to, amount);
    }

    /// @notice sets the wrap fee for non host chains
    /// @dev fee precision is 1e5; a fee of 1e4 is 10%
    /// @param _fee the new fee amount
    function setMintFee(uint256 _fee) external onlyOwner {
        emit MintFeeUpdated(mintFee, _fee);
        mintFee = _fee;
    }

    /// @notice sets the wrap cap
    /// @param _cap the new cap amount
    function setMintCap(uint256 _cap) external onlyOwner {
        if (_cap < totalSupply()) revert CapNotValid();
        emit MintCapUpdated(mintCap, _cap);
        mintCap = _cap;
    }

    /// @notice updates a connected chain whitelist status
    /// @param _chain the block.chainid of that specific chain
    function setConnectedChain(uint256 _chain) external onlyOwner {
        emit ConnectedChainStatusUpdated(_chain, connectedChains[_chain], true);
        connectedChains[_chain] = true;
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

    // ************************* //
    // *** PRIVATE FUNCTIONS *** //
    // ************************* //
    function _checkAndExtractFees(
        uint256 _amount
    ) private returns (uint256 feeAmount) {
        feeAmount = 0;

        // not on host chain; extract fee
        // fees are used to rebalance liquidity to host chain
        if (block.chainid != hostChainID && mintFee > 0) {
            feeAmount = (_amount * mintFee) / _FEE_PRECISION;
            if (feeAmount > 0) {
                if (erc20 == address(0)) {
                    vault.registerFees{value: feeAmount}(feeAmount);
                } else {
                    vault.registerFees(feeAmount);
                }
            }
        }
    }
}
