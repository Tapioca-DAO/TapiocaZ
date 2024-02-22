// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Tapioca
import {BaseTapiocaOmnichainEngine} from "tapioca-periph/tapiocaOmnichainEngine/BaseTapiocaOmnichainEngine.sol";
import {TOFTInitStruct, IToftVault} from "tapioca-periph/interfaces/oft/ITOFT.sol";
import {PearlmitHandler} from "tapioca-periph/pearlmit/PearlmitHandler.sol";
import {IYieldBox} from "tapioca-periph/interfaces/yieldbox/IYieldBox.sol";
import {ICluster} from "tapioca-periph/interfaces/periph/ICluster.sol";
import {BaseTOFTTokenMsgType} from "./BaseTOFTTokenMsgType.sol";
import {ModuleManager} from "./modules/ModuleManager.sol";

/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

/**
 * @title BaseTOFT
 * @author TapiocaDAO
 * @notice Base TOFT contract for LZ V2
 */
abstract contract BaseTOFT is ModuleManager, PearlmitHandler, BaseTapiocaOmnichainEngine, BaseTOFTTokenMsgType {
    using SafeERC20 for IERC20;

    IYieldBox public immutable yieldBox;
    IToftVault public immutable vault;
    uint256 public immutable hostEid;
    address public immutable erc20;
    ICluster public cluster;

    error TOFT_AllowanceNotValid();
    error TOFT_NotValid();
    error TOFT_VaultWrongERC20();
    error TOFT_VaultWrongOwner();

    constructor(TOFTInitStruct memory _data)
        BaseTapiocaOmnichainEngine(_data.name, _data.symbol, _data.endpoint, _data.delegate, _data.extExec, _data.pearlmit)
    {
        yieldBox = IYieldBox(_data.yieldBox);
        cluster = ICluster(_data.cluster);
        hostEid = _data.hostEid;
        erc20 = _data.erc20;
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
        // IERC20(erc20).safeTransferFrom(_fromAddress, address(vault), _amount);
        bool isErr = pearlmit.transferFromERC20(_fromAddress, address(vault), erc20, _amount);
        if (isErr) revert TOFT_NotValid();
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
