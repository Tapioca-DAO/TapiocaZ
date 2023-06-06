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
import {IUSDOBase} from "tapioca-periph/contracts/interfaces/IUSDO.sol";

contract BaseTOFTStorage is OFTV2 {
    // ************ //
    // *** VARS *** //
    // ************ //
    /// @notice The YieldBox address.
    IYieldBoxBase public yieldBox;
    /// @notice The ERC20 to wrap.
    address public erc20;
    /// @notice The host chain ID of the ERC20
    uint256 public hostChainID;
    /// @notice Decimal cache number of the ERC20.
    uint8 internal _decimalCache;

    uint16 internal constant PT_YB_SEND_STRAT = 770;
    uint16 internal constant PT_YB_RETRIEVE_STRAT = 771;
    uint16 internal constant PT_YB_SEND_SGL_BORROW = 775;
    uint16 internal constant PT_LEVERAGE_MARKET_DOWN = 776;

    receive() external payable {}

    constructor(
        address _lzEndpoint,
        address _erc20,
        IYieldBoxBase _yieldBox,
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
    }
}
