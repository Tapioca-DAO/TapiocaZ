import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import { time } from '@nomicfoundation/hardhat-network-helpers';
import { impersonateAccount, registerFork, setBalance } from '../test.utils';

describe.skip('Balancer fork', () => {
    describe('core', async () => {
        it('should check chain', async () => {
            const { balancer } = await loadFixture(registerFork);

            const stargateRouter = await ethers.getContractAt(
                'IStargateRouter',
                await balancer.routerETH(),
            );
            const poolId = await stargateRouter.poolId();
            expect(poolId.eq(13)).to.be.true;
        });

        it('should be able to add connected chains', async () => {
            const { tapiocaWrapper1, tOft1, tOft2, balancer } =
                await loadFixture(registerFork);

            let path = hre.ethers.utils.solidityPack(
                ['address', 'address'],
                [tOft1.address, tOft2.address],
            );
            let encodedTX = (
                await hre.ethers.getContractFactory('mTapiocaOFT')
            ).interface.encodeFunctionData('setTrustedRemote', [1, path]);
            await tapiocaWrapper1.executeTOFT(tOft1.address, encodedTX, true);

            await expect(
                balancer.initConnectedOFT(
                    tOft1.address,
                    1,
                    tOft2.address,
                    ethers.utils.defaultAbiCoder.encode(
                        ['uint256', 'uint256'],
                        [1, 1],
                    ),
                ),
            ).to.be.revertedWithCustomError(balancer, 'DestinationOftNotValid');

            path = hre.ethers.utils.solidityPack(
                ['address', 'address'],
                [tOft2.address, tOft1.address],
            );
            encodedTX = (
                await hre.ethers.getContractFactory('mTapiocaOFT')
            ).interface.encodeFunctionData('setTrustedRemote', [1, path]);
            await tapiocaWrapper1.executeTOFT(tOft1.address, encodedTX, true);

            await balancer.initConnectedOFT(
                tOft1.address,
                1,
                tOft2.address,
                ethers.utils.defaultAbiCoder.encode(
                    ['uint256', 'uint256'],
                    [1, 1],
                ),
            );

            const connected = (await balancer.connectedOFTs(tOft1.address, 1))
                .dstOft;
            expect(connected.toLowerCase()).to.eq(tOft2.address.toLowerCase());
        });
    });

    describe('rebalance', async () => {
        it.skip('should route funds to another OFT', async () => {
            const {
                tapiocaWrapper1,
                tapiocaWrapper2,
                tOft1,
                tOft2,
                balancer,
                deployer,
            } = await loadFixture(registerFork);

            const path = hre.ethers.utils.solidityPack(
                ['address', 'address'],
                [tOft2.address, tOft1.address],
            );
            const encodedTX = (
                await hre.ethers.getContractFactory('TapiocaOFT')
            ).interface.encodeFunctionData('setTrustedRemote', [1, path]);

            await tapiocaWrapper1.executeTOFT(tOft1.address, encodedTX, true);

            const txData = tOft1.interface.encodeFunctionData(
                'updateBalancerState',
                [balancer.address, true],
            );
            await expect(
                tapiocaWrapper1.executeTOFT(tOft1.address, txData, true),
            ).to.not.be.reverted;

            await expect(
                balancer.initConnectedOFT(
                    tOft1.address,
                    1,
                    tOft2.address,
                    ethers.utils.defaultAbiCoder.encode(
                        ['uint256', 'uint256'],
                        [1, 1],
                    ),
                ),
            ).to.not.be.reverted;

            const amountNo = 1;
            const amount = ethers.utils.parseEther(amountNo.toString());
            await setBalance(tOft1.address, 1);

            const balance = await ethers.provider.getBalance(tOft1.address);
            expect(balance.eq(amount)).to.be.true;

            const balanceOft2Before = await ethers.provider.getBalance(
                tOft2.address,
            );
            expect(balanceOft2Before.eq(0)).to.be.true;

            await balancer.addRebalanceAmount(tOft1.address, 1, amount);
            const data = ethers.utils.defaultAbiCoder.encode(
                ['uint256', 'uint256'],
                [1, 1],
            );

            await expect(
                balancer.rebalance(tOft1.address, 1, 1e3, amount, data, {
                    value: 0,
                }),
            ).to.be.revertedWithCustomError(balancer, 'FeeAmountNotSet');

            //create mocked chain path
            const ownableContract = await ethers.getContractAt(
                'Ownable',
                await balancer.router(),
            );

            await impersonateAccount(await ownableContract.owner());
            const stargateRouterOwner = await ethers.getSigner(
                await ownableContract.owner(),
            );

            const stargateRouter = await ethers.getContractAt(
                'IStargateRouter',
                await balancer.router(),
            );

            await stargateRouter
                .connect(stargateRouterOwner)
                .createChainPath(13, 101, 13, 1);

            await stargateRouter
                .connect(stargateRouterOwner)
                .activateChainPath(13, 101, 13);

            const stargateEthVault = await ethers.getContractAt(
                'IStargateEthVault',
                process.env.STARGATE_ETH_VAULT!,
            );
            await stargateEthVault.deposit({ value: amount.mul(4) });

            const sgEthBalance = await stargateEthVault.balanceOf(
                deployer.address,
            );
            expect(sgEthBalance.eq(amount.mul(4))).to.be.true;

            await stargateEthVault.approve(
                stargateRouter.address,
                amount.mul(4),
            );
            await stargateRouter.addLiquidity(
                13,
                amount.mul(4),
                deployer.address,
            );

            await impersonateAccount(await stargateRouter.bridge());
            const stargateRouterBridge = await ethers.getSigner(
                await stargateRouter.bridge(),
            );

            await setBalance(stargateRouterBridge.address, amountNo * 4);

            await stargateRouter
                .connect(stargateRouterBridge)
                .creditChainPath(101, 13, 13, {
                    credits: amount.mul(4),
                    idealBalance: amount.mul(4),
                });

            hre.tracer.enabled = true;
            await balancer.rebalance(tOft1.address, 101, 1e3, amount, data, {
                value: amount.div(2),
            });
            hre.tracer.enabled = false;
            const balanceOft2After = await ethers.provider.getBalance(
                tOft2.address,
            );
            expect(balanceOft2After.eq(amount)).to.be.true;

            const balanceOft0After = await ethers.provider.getBalance(
                tOft1.address,
            );
            expect(balanceOft0After.eq(0)).to.be.true;

            //this won't work due to the local setup, but it helped fixing some issues w.r.t the Balancer.sol contract
        });
    });
});
