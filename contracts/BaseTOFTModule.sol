// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

//LZ
import "tapioca-sdk/dist/contracts/token/oft/v2/OFTV2.sol";

//OZ
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

//TAPIOCA
import "tapioca-periph/contracts/interfaces/IYieldBoxBase.sol";

contract BaseTOFTModule is OFTV2 {

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

    // ********************** //
    // *** VIEW FUNCTIONS *** //
    // ********************** //
    /// @notice decimal number of the ERC20
    function decimals() public view override returns (uint8) {
        if (_decimalCache == 0) return 18; //temporary fix for LZ _sharedDecimals check
        return _decimalCache;
    }


    // ********************** //
    // *** INTERNAL FUNCTIONS *** //
    // ********************** //
    function _safeTransferETH(address to, uint256 amount) internal {
        (bool sent, ) = to.call{value: amount}("");
        require(sent, "TOFT_failed");
    }



}
