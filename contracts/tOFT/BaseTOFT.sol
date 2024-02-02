// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Tapioca
import {BaseTapiocaOmnichainEngine} from "tapioca-periph/tapiocaOmnichainEngine/BaseTapiocaOmnichainEngine.sol";
import {IYieldBox} from "tapioca-periph/interfaces/yieldbox/IYieldBox.sol";
import {BaseTOFTTokenMsgType} from "contracts/BaseTOFTTokenMsgType.sol";
import {ICluster} from "tapioca-periph/interfaces/periph/ICluster.sol";
import {ModuleManager} from "contracts/modules/ModuleManager.sol";
import {TOFTExtExec} from "contracts/extensions/TOFTExtExec.sol";
import {ITOFT, TOFTInitStruct} from "contracts/ITOFT.sol";
import {TOFTVault} from "contracts/TOFTVault.sol";

/*
__/\\\\\\\\\\\\\\\_____/\\\\\\\\\_____/\\\\\\\\\\\\\____/\\\\\\\\\\\_______/\\\\\_____________/\\\\\\\\\_____/\\\\\\\\\____        
 _\///////\\\/////____/\\\\\\\\\\\\\__\/\\\/////////\\\_\/////\\\///______/\\\///\\\________/\\\////////____/\\\\\\\\\\\\\__       
  _______\/\\\________/\\\/////////\\\_\/\\\_______\/\\\_____\/\\\_______/\\\/__\///\\\____/\\\/____________/\\\/////////\\\_      
   _______\/\\\_______\/\\\_______\/\\\_\/\\\\\\\\\\\\\/______\/\\\______/\\\______\//\\\__/\\\_____________\/\\\_______\/\\\_     
    _______\/\\\_______\/\\\\\\\\\\\\\\\_\/\\\/////////________\/\\\_____\/\\\_______\/\\\_\/\\\_____________\/\\\\\\\\\\\\\\\_    
     _______\/\\\_______\/\\\/////////\\\_\/\\\_________________\/\\\_____\//\\\______/\\\__\//\\\____________\/\\\/////////\\\_   
      _______\/\\\_______\/\\\_______\/\\\_\/\\\_________________\/\\\______\///\\\__/\\\_____\///\\\__________\/\\\_______\/\\\_  
       _______\/\\\_______\/\\\_______\/\\\_\/\\\______________/\\\\\\\\\\\____\///\\\\\/________\////\\\\\\\\\_\/\\\_______\/\\\_ 
        _______\///________\///________\///__\///______________\///////////_______\/////_____________\/////////__\///________\///__

*/

/**
 * @title BaseTOFT
 * @author TapiocaDAO
 * @notice Base TOFT contract for LZ V2
 */
abstract contract BaseTOFT is ModuleManager, BaseTapiocaOmnichainEngine, BaseTOFTTokenMsgType {
    using SafeERC20 for IERC20;

    // LZ packets
    uint16 internal constant PT_YB_APPROVE_ASSET = 600; // Use for YieldBox 'setApprovalForAsset(true)' operation
    uint16 internal constant PT_YB_APPROVE_ALL = 601; // Use for YieldBox 'setApprovalForAll(true)' operation
    uint16 internal constant PT_MARKET_PERMIT = 602; // Use for market.permitLend() operation

    uint16 internal constant PT_MARKET_REMOVE_COLLATERAL = 800; // Use for remove collateral from a market available on another chain
    uint16 internal constant PT_YB_SEND_SGL_BORROW = 801; // Use fror send to YB and/or borrow from a market available on another chain
    uint16 internal constant PT_LEVERAGE_MARKET_DOWN = 802; // Use for leverage sell on a market available on another chain
    uint16 internal constant PT_TAP_EXERCISE = 803; // Use for exercise options on tOB available on another chain
    uint16 internal constant PT_SEND_PARAMS = 804; // Use for perform a normal OFT send but with a custom payload

    TOFTExtExec public immutable toftExtExec;
    IYieldBox public immutable yieldBox;
    TOFTVault public immutable vault;
    uint256 public immutable hostEid;
    address public immutable erc20;
    ICluster public cluster;

    error TOFT_AllowanceNotValid();
    error TOFT_NotValid();

    constructor(TOFTInitStruct memory _data)
        BaseTapiocaOmnichainEngine(_data.name, _data.symbol, _data.endpoint, _data.owner)
    {
        yieldBox = IYieldBox(_data.yieldBox);
        cluster = ICluster(_data.cluster);
        hostEid = _data.hostEid;
        erc20 = _data.erc20;
        vault = new TOFTVault(_data.erc20);

        toftExtExec = new TOFTExtExec();
    }

    /**
     * @notice set the Cluster address.
     * @param _cluster the new Cluster address
     */
    function setCluster(address _cluster) external virtual onlyOwner {
        cluster = ICluster(_cluster);
    }

    function _wrap(address _fromAddress, address _toAddress, uint256 _amount, uint256 _feeAmount) internal virtual {
        if (_fromAddress != msg.sender) {
            if (allowance(_fromAddress, msg.sender) < _amount) {
                revert TOFT_AllowanceNotValid();
            }
            _spendAllowance(_fromAddress, msg.sender, _amount);
        }
        if (_amount == 0) revert TOFT_NotValid();
        IERC20(erc20).safeTransferFrom(_fromAddress, address(vault), _amount);
        _mint(_toAddress, _amount - _feeAmount);
    }

    function _wrapNative(address _toAddress, uint256 _amount, uint256 _feeAmount) internal virtual {
        vault.depositNative{value: _amount}();
        _mint(_toAddress, _amount - _feeAmount);
    }

    function _unwrap(address _toAddress, uint256 _amount) internal virtual {
        _burn(msg.sender, _amount);
        vault.withdraw(_toAddress, _amount);
    }
}
