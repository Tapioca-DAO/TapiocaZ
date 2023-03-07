// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../interfaces/IStargateRouter.sol";
import "./ERC20Mock.sol";

contract StargateRouterETHMock {
    ERC20Mock public token;
    IStargateRouterBase public router;

    constructor(IStargateRouterBase _router, ERC20Mock _token) {}

    function swapETH(
        uint16 _dstChainId, // destination Stargate chainId
        address payable _refundAddress, // refund additional messageFee to this address
        bytes calldata _toAddress, // the receiver of the destination ETH
        uint256 _amountLD, // the amount, in Local Decimals, to be swapped
        uint256 _minAmountLD // the minimum amount accepted out on destination
    ) external payable {
        require(
            msg.value > _amountLD,
            "Stargate: msg.value must be > _amountLD"
        );
        IStargateRouterBase.lzTxObj memory data;
        //simulate WETH wrap
        token.mint(address(this), _amountLD);
        token.approve(address(router), _amountLD);
        router.swap(
            _dstChainId,
            1,
            1,
            _refundAddress,
            _amountLD,
            _minAmountLD,
            data,
            _toAddress,
            ""
        );
    }
}
