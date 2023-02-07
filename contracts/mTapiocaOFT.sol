// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import './TapiocaWrapper.sol';
import './BaseTOFT.sol';
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

//Merged tOFT (eg: arbitrum eth, mainnet eth, optimism eth)
contract mTapiocaOFT is BaseTOFT {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;

    // ************ //
    // *** VARS *** //
    // ************ //
    /// @notice The TapiocaWrapper contract, owner of this contract.
    TapiocaWrapper public tapiocaWrapper;
    /// @notice allowed chains where you can unwrap your TOFT
    mapping(uint256 => bool) public connectedChains;
    /// @notice map of approved balancers
    /// @dev a balancer can extract the underlying
    mapping(address => bool) public balancers;

    // ************** //
    // *** ERRORS *** //
    // ************** //
    /// @notice Code executed not on one of the allowed chains
    error TOFT_NotAllowedChain();

    // ************** //
    // *** EVENTS *** //
    // ************** //
    event ConnectedChainStatusUpdated(uint256 _chain, bool _old, bool _new);
    event BalancerStatusUpdated(
        address indexed _balancer,
        bool _bool,
        bool _new
    );
    event Rebalancing(
        address indexed _balancer,
        uint256 _amount,
        bool _isNative
    );

    // ******************//
    // *** MODIFIERS *** //
    // ***************** //

    /// @notice Require that the caller is on the host chain of the ERC20.
    modifier onlyAllowedChain() {
        if (!connectedChains[block.chainid]) {
            revert TOFT_NotAllowedChain();
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
        BaseTOFT(
            _lzEndpoint,
            _isNative,
            _erc20,
            _yieldBox,
            _name,
            _symbol,
            _decimal,
            _hostChainID
        )
    {
        tapiocaWrapper = TapiocaWrapper(msg.sender);

        if (block.chainid == _hostChainID) {
            connectedChains[_hostChainID] = true;
            emit ConnectedChainStatusUpdated(_hostChainID, false, true);
        }
    }

    // ********************** //
    // *** VIEW FUNCTIONS *** //
    // ********************** //
    /// @notice Return the output amount of an ERC20 token wrap operation.
    function wrappedAmount(uint256 _amount) public view returns (uint256) {
        return
            _amount -
            estimateFees(
                tapiocaWrapper.mngmtFee(),
                tapiocaWrapper.mngmtFeeFraction(),
                _amount
            );
    }

    // ************************ //
    // *** PUBLIC FUNCTIONS *** //
    // ************************ //
    /// @notice Wrap an ERC20 with a 1:1 ratio with a fee if existing.
    /// @dev Since it can be executed only on the main chain, if an address exists on the OP chain it will not allowed to wrap.
    /// @param _toAddress The address to wrap the ERC20 to.
    /// @param _amount The amount of ERC20 to wrap.
    function wrap(address _toAddress, uint256 _amount) external onlyHostChain {
        _wrap(
            _toAddress,
            _amount,
            tapiocaWrapper.mngmtFee(),
            tapiocaWrapper.mngmtFeeFraction()
        );
    }

    /// @notice Wrap a native token with a 1:1 ratio with a fee if existing.
    /// @dev Since it can be executed only on the host chain, if an address exists on the linked chain it will not allowed to wrap.
    /// @param _toAddress The address to wrap the tokens to.
    function wrapNative(address _toAddress) external payable onlyHostChain {
        _wrapNative(
            _toAddress,
            tapiocaWrapper.mngmtFee(),
            tapiocaWrapper.mngmtFeeFraction()
        );
    }

    /// @notice Harvest the fees collected by the contract. Called only on host chain.
    function harvestFees() external onlyHostChain {
        _harvestFees(address(tapiocaWrapper.owner()));
    }

    /// @notice Unwrap an ERC20/Native with a 1:1 ratio. Called only on host chain.
    /// @param _toAddress The address to unwrap the tokens to.
    /// @param _amount The amount of tokens to unwrap.
    function unwrap(address _toAddress, uint256 _amount)
        external
        onlyAllowedChain
    {
        _unwrap(_toAddress, _amount);
    }

    // *********************** //
    // *** OWNER FUNCTIONS *** //
    // *********************** //
    /// @notice updates a connected chain whitelist status
    /// @param _chain the block.chainid of that specific chain
    /// @param _status the new whitelist status
    function updateConnectedChain(uint256 _chain, bool _status)
        external
        onlyOwner
    {
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
    function updateBalancerState(address _balancer, bool _status)
        external
        onlyOwner
    {
        emit BalancerStatusUpdated(_balancer, balancers[_balancer], _status);
        balancers[_balancer] = _status;
    }

    /// @notice extracts the underlying token/native for rebalancing
    /// @param _amount the amount used for rebalancing
    function extractUnderlying(uint256 _amount) external {
        require(balancers[msg.sender], 'TapiocaOFT: not authorized');
        
        if (isNative) {
            TransferLib.safeTransferETH(msg.sender, _amount);
        } else {
            erc20.safeTransfer(msg.sender, _amount);
        }

        emit Rebalancing(msg.sender, _amount, isNative);
    }
}
