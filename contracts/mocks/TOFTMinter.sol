// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "../interfaces/ITapiocaOFT.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20WithDecimal is IERC20 {
    function decimals() external view returns (uint8);
}

contract TOFTMinter is Ownable {
    ITapiocaOFT public OFT;
    IERC20WithDecimal public token;

    mapping(address => uint256) public mintedAt;
    uint256 public mintWindow = 24 hours;
    uint256 public mintLimit;

    constructor(ITapiocaOFT _oft) {
        OFT = _oft;
        token = IERC20WithDecimal(address(_oft.erc20()));

        uint8 _decimals = token.decimals();
        mintLimit = 1000 * (10 ** _decimals);
    }

    function freeMint(uint256 _val) external {
        require(_val <= mintLimit, "TOFTMinter: amount too big");
        require(
            mintedAt[msg.sender] + mintWindow <= block.timestamp,
            "TOFTMinter: too early"
        );

        mintedAt[msg.sender] = block.timestamp;

        _mint(msg.sender, _val);
    }

    function mintTo(address _to, uint256 _amount) external onlyOwner {
        _mint(_to, _amount);
    }

    function _mint(address _to, uint256 _amount) internal {
        token.approve(address(OFT), _amount);
        OFT.wrap(address(this), _to, _amount);
    }

    function updateMintLimit(uint256 _newVal) external onlyOwner {
        mintWindow = _newVal;
    }

    function updateMintWindow(uint256 _newVal) external onlyOwner {
        mintLimit = _newVal;
    }
}
