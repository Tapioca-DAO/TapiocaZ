// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;

// External
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {BytesLib} from "solidity-bytes-utils/contracts/BytesLib.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

// Tapioca
import {
    TOFTInitStruct,
    MarketBorrowMsg,
    MarketRemoveCollateralMsg,
    LeverageUpActionMsg
} from "tapioca-periph/interfaces/oft/ITOFT.sol";
import {
    IMagnetar,
    MagnetarCall,
    DepositAddCollateralAndBorrowFromMarketData,
    MagnetarAction
} from "tapioca-periph/interfaces/periph/IMagnetar.sol";
import {MagnetarCollateralModule} from "tapioca-periph/Magnetar/modules/MagnetarCollateralModule.sol";
import {MagnetarYieldBoxModule} from "tapioca-periph/Magnetar/modules/MagnetarYieldBoxModule.sol";
import {IMarketHelper} from "tapioca-periph/interfaces/bar/IMarketHelper.sol";
import {IYieldBox} from "tapioca-periph/interfaces/yieldbox/IYieldBox.sol";
import {IMarket, Module} from "tapioca-periph/interfaces/bar/IMarket.sol";
import {TOFTMsgCodec} from "../libraries/TOFTMsgCodec.sol";
import {BaseTOFT} from "../BaseTOFT.sol";


/*

████████╗ █████╗ ██████╗ ██╗ ██████╗  ██████╗ █████╗ 
╚══██╔══╝██╔══██╗██╔══██╗██║██╔═══██╗██╔════╝██╔══██╗
   ██║   ███████║██████╔╝██║██║   ██║██║     ███████║
   ██║   ██╔══██║██╔═══╝ ██║██║   ██║██║     ██╔══██║
   ██║   ██║  ██║██║     ██║╚██████╔╝╚██████╗██║  ██║
   ╚═╝   ╚═╝  ╚═╝╚═╝     ╚═╝ ╚═════╝  ╚═════╝╚═╝  ╚═╝
   
*/

/**
 * @title TOFTMarketReceiverModule
 * @author TapiocaDAO
 * @notice TOFT Market module
 */
contract TOFTMarketReceiverModule is BaseTOFT {
    using SafeERC20 for IERC20;
    using BytesLib for bytes;
    using SafeCast for uint256;

    error TOFTMarketReceiverModule_NotAuthorized(address invalidAddress);

    event BorrowReceived(
        address indexed user, address indexed market, uint256 indexed amount, bool deposit, bool withdraw
    );

    event RemoveCollateralReceived(address indexed user, address indexed market, uint256 indexed amount, bool withdraw);

    event LeverageUpReceived(
        address indexed user, address indexed market, uint256 indexed amount, uint256 supplyAmount
    );

    constructor(TOFTInitStruct memory _data) BaseTOFT(_data) {}

    /**
     * @notice Calls `buyCollateral` on a market
     * @param srcChainSender The address of the sender on the source chain.
     * @param _data The call data containing info about the operation.
     *      - user::address: Address to leverage for.
     *      - market::address: Address of the market.
     *      - borrowAmount::address: Borrow amount to leverage with.
     *      - supplyAmount::address: Extra asset amount used for the leverage operation.
     *      - executorData::bytes: Leverage executor data.
     */
    function leverageUpReceiver(address srcChainSender, bytes memory _data) public payable {
        LeverageUpActionMsg memory msg_ = TOFTMsgCodec.decodeLeverageUpMsg(_data);

        /**
        * @dev validate data
        */
        msg_ = _validateLeverageUpReceiver(msg_, srcChainSender);

        /**
        * @dev executes market action
        */
        _marketLeverage(msg_);

        emit LeverageUpReceived(msg_.user, msg_.market, msg_.borrowAmount, msg_.supplyAmount);
    }
    
    /**
     * @notice Calls depositAddCollateralAndBorrowFromMarket on Magnetar
     * @param srcChainSender The address of the sender on the source chain.
     * @param _data The call data containing info about the operation.
     *      - from::address: Address to debit tokens from.
     *      - to::address: Address to execute operations on.
     *      - borrowParams::struct: Borrow operation related params.
     *      - withdrawParams::struct: Withdraw related params.
     */
    function marketBorrowReceiver(address srcChainSender, bytes memory _data) public payable {
        MarketBorrowMsg memory msg_ = TOFTMsgCodec.decodeMarketBorrowMsg(_data);

        /**
        * @dev validate data
        */
        msg_ = _validateMarketBorrowReceiver(msg_, srcChainSender);

        /**
        * @dev execute market's action
        */
        _marketBorrow(msg_);

        emit BorrowReceived(
            msg_.user,
            msg_.borrowParams.market,
            msg_.borrowParams.amount,
            msg_.borrowParams.deposit,
            msg_.withdrawParams.withdraw
        );
    }

    /**
     * @notice Performs market.removeCollateral()
     * @param srcChainSender The address of the sender on the source chain.
     * @param _data The call data containing info about the operation.
     *      - from::address: Address to debit tokens from.
     *      - to::address: Address to execute operations on.
     *      - removeParams::struct: Remove collateral operation related params.
     *      - withdrawParams::struct: Withdraw related params.
     */
    function marketRemoveCollateralReceiver(address srcChainSender, bytes memory _data) public payable {
        MarketRemoveCollateralMsg memory msg_ = TOFTMsgCodec.decodeMarketRemoveCollateralMsg(_data);

        /**
        * @dev validate data
        */
        _validateMarketRemoveCollateral(msg_, srcChainSender);

        /**
        * @dev execute market's action
        */
        _marketRemoveCollateral(msg_);

        /**
        * @dev try withdraw through `Magnetar`
        */
        if (msg_.withdrawParams.withdraw) {
            _magnetarWithdraw(msg_);
        }

        emit RemoveCollateralReceived(
            msg_.user, msg_.removeParams.market, msg_.removeParams.amount, msg_.withdrawParams.withdraw
        );
    }

    function _validateLeverageUpReceiver(LeverageUpActionMsg memory msg_, address srcChainSender) private returns (LeverageUpActionMsg memory) {

        _checkWhitelistStatus(msg_.market);
        _checkWhitelistStatus(msg_.marketHelper);

        msg_.borrowAmount = _toLD(msg_.borrowAmount.toUint64());
        if (msg_.supplyAmount > 0) {
            msg_.supplyAmount = _toLD(msg_.supplyAmount.toUint64());
        }

        _validateAndSpendAllowance(msg_.user, srcChainSender, msg_.borrowAmount);

        return msg_;
    }

    function _marketLeverage(LeverageUpActionMsg memory msg_) private {
        (Module[] memory modules, bytes[] memory calls) = IMarketHelper(msg_.marketHelper).buyCollateral(
            msg_.user, msg_.borrowAmount, msg_.supplyAmount, msg_.executorData
        );
        if (msg_.supplyAmount > 0) {
            IYieldBox yb = IYieldBox(IMarket(msg_.market)._yieldBox());
            yb.depositAsset(IMarket(msg_.market)._assetId(), msg_.user, msg_.user, msg_.supplyAmount, 0);
        }
        IMarket(msg_.market).execute(modules, calls, true);
    }

     function _validateMarketBorrowReceiver(MarketBorrowMsg memory msg_, address srcChainSender) private returns (MarketBorrowMsg memory) {
        _checkWhitelistStatus(msg_.borrowParams.marketHelper);
        _checkWhitelistStatus(msg_.borrowParams.magnetar);
        _checkWhitelistStatus(msg_.borrowParams.market);

        msg_.borrowParams.amount = _toLD(msg_.borrowParams.amount.toUint64());
        msg_.borrowParams.borrowAmount = _toLD(msg_.borrowParams.borrowAmount.toUint64());

        _validateAndSpendAllowance(msg_.user, srcChainSender, msg_.borrowParams.amount);

        return msg_;
    }

    function _marketBorrow(MarketBorrowMsg memory msg_) private {
        bytes memory call = abi.encodeWithSelector(
            MagnetarCollateralModule.depositAddCollateralAndBorrowFromMarket.selector,
            DepositAddCollateralAndBorrowFromMarketData(
                msg_.borrowParams.market,
                msg_.borrowParams.marketHelper,
                msg_.user,
                msg_.borrowParams.amount,
                msg_.borrowParams.borrowAmount,
                msg_.borrowParams.deposit,
                msg_.withdrawParams
            )
        );
        MagnetarCall[] memory magnetarCall = new MagnetarCall[](1);
        magnetarCall[0] = MagnetarCall({
            id: uint8(MagnetarAction.CollateralModule),
            target: msg_.borrowParams.market,
            value: msg.value,
            call: call
        });
        IMagnetar(payable(msg_.borrowParams.magnetar)).burst{value: msg.value}(magnetarCall);
    }

    function _validateMarketRemoveCollateral(MarketRemoveCollateralMsg memory msg_, address srcChainSender) private returns (MarketRemoveCollateralMsg memory) {
        _checkWhitelistStatus(msg_.removeParams.market);
        _checkWhitelistStatus(msg_.removeParams.marketHelper);
        _checkWhitelistStatus(msg_.removeParams.magnetar);

        msg_.removeParams.amount = _toLD(msg_.removeParams.amount.toUint64());

        _validateAndSpendAllowance(msg_.user, srcChainSender, msg_.removeParams.amount);
        
        return msg_;
    }

    function _marketRemoveCollateral(MarketRemoveCollateralMsg memory msg_) private {
        address ybAddress = IMarket(msg_.removeParams.market)._yieldBox();
        uint256 assetId = IMarket(msg_.removeParams.market)._collateralId();

        uint256 share = IYieldBox(ybAddress).toShare(assetId, msg_.removeParams.amount, false);

        (Module[] memory modules, bytes[] memory calls) = IMarketHelper(msg_.removeParams.marketHelper)
            .removeCollateral(msg_.user, msg_.withdrawParams.withdraw ? msg_.removeParams.magnetar : msg_.user, share);
        IMarket(msg_.removeParams.market).execute(modules, calls, true);
    }
    function _magnetarWithdraw(MarketRemoveCollateralMsg memory msg_) private {
        bytes memory call =
            abi.encodeWithSelector(MagnetarYieldBoxModule.withdrawHere.selector, msg_.withdrawParams);
        MagnetarCall[] memory magnetarCall = new MagnetarCall[](1);
        magnetarCall[0] = MagnetarCall({
            id: uint8(MagnetarAction.YieldBoxModule),
            target: address(this),
            value: msg.value,
            call: call
        });
        IMagnetar(payable(msg_.removeParams.magnetar)).burst{value: msg.value}(magnetarCall);
    }

    function _checkWhitelistStatus(address _addr) private view {
        if (_addr != address(0)) {
            if (!getCluster().isWhitelisted(0, _addr)) {
                revert TOFTMarketReceiverModule_NotAuthorized(_addr);
            }
        }
    }
}
