// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

//LZ
import "tapioca-sdk/dist/contracts/token/oft/v2/OFTV2.sol";
import "tapioca-sdk/dist/contracts/libraries/LzLib.sol";

//OZ
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

//TAPIOCA INTERFACES
import "tapioca-periph/contracts/interfaces/IYieldBoxBase.sol";
import "tapioca-periph/contracts/interfaces/ITapiocaOFT.sol";
import "tapioca-periph/contracts/interfaces/ICommonData.sol";
import "tapioca-periph/contracts/interfaces/ICluster.sol";
import {IUSDOBase} from "tapioca-periph/contracts/interfaces/IUSDO.sol";

contract BaseTOFTStorage is OFTV2 {
    // ************ //
    // *** VARS *** //
    // ************ //
    /// @notice The YieldBox address.
    IYieldBoxBase public yieldBox;
    /// @notice The Cluster address
    ICluster public cluster;
    /// @notice The ERC20 to wrap.
    address public erc20;
    /// @notice The host chain ID of the ERC20
    uint256 public hostChainID;
    /// @notice Decimal cache number of the ERC20.
    uint8 internal _decimalCache;

    uint16 internal constant PT_YB_SEND_STRAT = 770;
    uint16 internal constant PT_YB_RETRIEVE_STRAT = 771;
    uint16 internal constant PT_MARKET_REMOVE_COLLATERAL = 772;
    uint16 internal constant PT_YB_SEND_SGL_BORROW = 775;
    uint16 internal constant PT_LEVERAGE_MARKET_DOWN = 776;
    uint16 internal constant PT_TAP_EXERCISE = 777;
    uint16 internal constant PT_TRIGGER_SEND_FROM = 778;
    uint16 internal constant PT_APPROVE = 779;
    uint16 internal constant PT_SEND_FROM_PARAMS = 780;

    uint256 public SWAP_MAX_SLIPPAGE = 500; //5%
    uint256 internal constant SLIPPAGE_PRECISION = 1e4;

    enum Module {
        NonModule, //0
        Generic,
        Leverage,
        LeverageDestination,
        Strategy,
        StrategyDestination,
        Market,
        MarketDestination,
        Options,
        OptionsDestination
    }
    mapping(Module module => address moduleAddress) internal _moduleAddresses;

    receive() external payable {}

    constructor(
        address _lzEndpoint,
        address _erc20,
        IYieldBoxBase _yieldBox,
        ICluster _cluster,
        string memory _name,
        string memory _symbol,
        uint8 _decimal,
        uint256 _hostChainID
    )
        OFTV2(
            string(abi.encodePacked("TapiocaOFT-", _name)),
            string(abi.encodePacked("t", _symbol)),
            _decimal / 2,
            _lzEndpoint
        )
    {
        erc20 = _erc20;
        _decimalCache = _decimal;
        hostChainID = _hostChainID;
        yieldBox = _yieldBox;
        cluster = _cluster;
    }

    function setMaxSlippage(uint256 _slippage) external onlyOwner {
        SWAP_MAX_SLIPPAGE = _slippage;
    }

    function _assureMaxSlippage(
        uint256 amount,
        uint256 minAmount
    ) internal view {
        uint256 slippageMinAmount = amount -
            ((SWAP_MAX_SLIPPAGE * amount) / SLIPPAGE_PRECISION);
        require(minAmount >= slippageMinAmount, "TOFT_SLIPPAGE");
    }

    function _getRevertMsg(
        bytes memory _returnData
    ) internal pure returns (string memory) {
        if (_returnData.length > 1000) return "TOFT_LONG_REASON";

        // If the _res length is less than 68, then the transaction failed silently (without a revert message)
        if (_returnData.length < 68) return "TOFT_data";
        // solhint-disable-next-line no-inline-assembly
        assembly {
            // Slice the sighash.
            _returnData := add(_returnData, 0x04)
        }
        return abi.decode(_returnData, (string)); // All that remains is the revert string
    }
}
