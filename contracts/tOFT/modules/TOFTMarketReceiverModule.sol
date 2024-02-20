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
import {TOFTMsgCodec} from "contracts/tOFT/libraries/TOFTMsgCodec.sol";
import {BaseTOFT} from "contracts/tOFT/BaseTOFT.sol";

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
     * @param _data The call data containing info about the operation.
     *      - user::address: Address to leverage for.
     *      - market::address: Address of the market.
     *      - borrowAmount::address: Borrow amount to leverage with.
     *      - supplyAmount::address: Extra asset amount used for the leverage operation.
     *      - executorData::bytes: Leverage executor data.
     */
    function leverageUpReceiver(bytes memory _data) public payable {
        /// @dev decode received message
        LeverageUpActionMsg memory msg_ = TOFTMsgCodec.decodeLeverageUpMsg(_data);

        /// @dev 'market'
        _checkWhitelistStatus(msg_.market);

        msg_.borrowAmount = _toLD(msg_.borrowAmount.toUint64());
        if (msg_.supplyAmount > 0) {
            msg_.supplyAmount = _toLD(msg_.supplyAmount.toUint64());
        }

        approve(address(msg_.market), type(uint256).max);

        {
            (Module[] memory modules, bytes[] memory calls) = IMarketHelper(msg_.marketHelper).buyCollateral(
                msg_.user, msg_.borrowAmount, msg_.supplyAmount, msg_.executorData
            );
            IMarket(msg_.market).execute(modules, calls, true);
        }

        approve(address(msg_.market), 0);

        emit LeverageUpReceived(msg_.user, msg_.market, msg_.borrowAmount, msg_.supplyAmount);
    }

    /**
     * @notice Calls depositAddCollateralAndBorrowFromMarket on Magnetar
     * @param _data The call data containing info about the operation.
     *      - from::address: Address to debit tokens from.
     *      - to::address: Address to execute operations on.
     *      - borrowParams::struct: Borrow operation related params.
     *      - withdrawParams::struct: Withdraw related params.
     */
    function marketBorrowReceiver(bytes memory _data) public payable {
        /// @dev decode received message
        MarketBorrowMsg memory msg_ = TOFTMsgCodec.decodeMarketBorrowMsg(_data);

        _checkWhitelistStatus(msg_.borrowParams.marketHelper);
        _checkWhitelistStatus(msg_.borrowParams.magnetar);
        _checkWhitelistStatus(msg_.borrowParams.market);

        msg_.borrowParams.amount = _toLD(msg_.borrowParams.amount.toUint64());
        msg_.borrowParams.borrowAmount = _toLD(msg_.borrowParams.borrowAmount.toUint64());

        /// @dev use market helper to deposit, add collateral to market and withdrawTo
        approve(address(msg_.borrowParams.magnetar), msg_.borrowParams.amount);

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
            id: MagnetarAction.CollateralModule,
            target: msg_.borrowParams.market,
            value: msg.value,
            allowFailure: false,
            call: call
        });
        IMagnetar(payable(msg_.borrowParams.magnetar)).burst{value: msg.value}(magnetarCall);

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
     * @param _data The call data containing info about the operation.
     *      - from::address: Address to debit tokens from.
     *      - to::address: Address to execute operations on.
     *      - removeParams::struct: Remove collateral operation related params.
     *      - withdrawParams::struct: Withdraw related params.
     */
    function marketRemoveCollateralReceiver(bytes memory _data) public payable {
        /// @dev decode received message
        MarketRemoveCollateralMsg memory msg_ = TOFTMsgCodec.decodeMarketRemoveCollateralMsg(_data);

        _checkWhitelistStatus(msg_.removeParams.market);

        address ybAddress = IMarket(msg_.removeParams.market).yieldBox();
        uint256 assetId = IMarket(msg_.removeParams.market).collateralId();

        msg_.removeParams.amount = _toLD(msg_.removeParams.amount.toUint64());

        {
            uint256 share = IYieldBox(ybAddress).toShare(assetId, msg_.removeParams.amount, false);
            approve(msg_.removeParams.market, share);

            (Module[] memory modules, bytes[] memory calls) = IMarketHelper(msg_.removeParams.marketHelper)
                .removeCollateral(msg_.user, msg_.withdrawParams.withdraw ? msg_.removeParams.magnetar : msg_.user, share);
            IMarket(msg_.removeParams.market).execute(modules, calls, true);
        }

        {
            if (msg_.withdrawParams.withdraw) {
                _checkWhitelistStatus(msg_.removeParams.magnetar);

                bytes memory call =
                    abi.encodeWithSelector(MagnetarYieldBoxModule.withdrawToChain.selector, msg_.withdrawParams);
                MagnetarCall[] memory magnetarCall = new MagnetarCall[](1);
                magnetarCall[0] = MagnetarCall({
                    id: MagnetarAction.YieldBoxModule,
                    target: address(this),
                    value: msg.value,
                    allowFailure: false,
                    call: call
                });
                IMagnetar(payable(msg_.removeParams.magnetar)).burst{value: msg.value}(magnetarCall);
            }
        }

        emit RemoveCollateralReceived(
            msg_.user, msg_.removeParams.market, msg_.removeParams.amount, msg_.withdrawParams.withdraw
        );
    }

    function _checkWhitelistStatus(address _addr) private view {
        if (_addr != address(0)) {
            if (!cluster.isWhitelisted(0, _addr)) {
                revert TOFTMarketReceiverModule_NotAuthorized(_addr);
            }
        }
    }
}
