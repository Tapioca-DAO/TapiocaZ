import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import { setupFixture } from './fixtures';
import { time } from '@nomicfoundation/hardhat-network-helpers';

describe('Balancer', () => {
    describe('connectedOFTs', () => {
        it('should fail for unauthorized user', async () => {
            const { randomUser, mtapiocaOFT0, balancer } = await loadFixture(
                setupFixture,
            );

            expect(randomUser.address).to.not.eq(ethers.constants.AddressZero);

            await expect(
                balancer
                    .connect(randomUser)
                    .initConnectedOFT(
                        mtapiocaOFT0.address,
                        1,
                        mtapiocaOFT0.address,
                        ethers.utils.defaultAbiCoder.encode(
                            ['uint256', 'uint256'],
                            [1, 1],
                        ),
                    ),
            ).to.be.reverted;
        });

        it('should be able to add connected chains', async () => {
            const { mtapiocaOFT0, balancer } = await loadFixture(setupFixture);

            await balancer.initConnectedOFT(
                mtapiocaOFT0.address,
                1,
                mtapiocaOFT0.address,
                ethers.utils.defaultAbiCoder.encode(
                    ['uint256', 'uint256'],
                    [1, 1],
                ),
            );

            const connected = (
                await balancer.connectedOFTs(mtapiocaOFT0.address, 1)
            ).dstOft;
            expect(connected.toLowerCase()).to.eq(
                mtapiocaOFT0.address.toLowerCase(),
            );
        });
    });

    describe('rebalance', async () => {
        it('should fail for unauthorized user', async () => {
            const { randomUser, mtapiocaOFT0, balancer } = await loadFixture(
                setupFixture,
            );

            await expect(
                balancer
                    .connect(randomUser)
                    .rebalance(
                        mtapiocaOFT0.address,
                        1,
                        1,
                        1,
                        ethers.utils.toUtf8Bytes(''),
                    ),
            ).to.be.reverted;

            await expect(
                balancer.rebalance(
                    mtapiocaOFT0.address,
                    1,
                    1,
                    1,
                    ethers.utils.toUtf8Bytes(''),
                ),
            ).to.be.revertedWithCustomError(balancer, 'DestinationNotValid');
        });

        it('should route funds to another OFT', async () => {
            const {
                mtapiocaOFT0,
                mtapiocaOFT10,
                balancer,
                mErc20Mock,
                stargateRouterMock,
            } = await loadFixture(setupFixture);

            const amount = ethers.utils.parseEther('1');
            await time.increase(86401);

            const vault = await mtapiocaOFT0.vault();
            await mErc20Mock.freeMint(amount);
            await mErc20Mock.transfer(vault, amount);

            const balance = await mErc20Mock.balanceOf(vault);
            expect(balance.eq(amount)).to.be.true;

            const vault10 = await mtapiocaOFT10.vault();
            const balanceOft10Before = await mErc20Mock.balanceOf(vault10);
            expect(balanceOft10Before.eq(0)).to.be.true;

            let ownerStateData = {
                stargateRouter: ethers.constants.AddressZero,
                mintFee: 0,
                mintCap: 0,
                connectedChain: 0,
                connectedChainState: false,
                balancerStateAddress: balancer.address,
                balancerState: true,
            };
            await mtapiocaOFT0.setOwnerState(ownerStateData);

            await expect(
                balancer.initConnectedOFT(
                    mtapiocaOFT0.address,
                    1,
                    mtapiocaOFT10.address,
                    ethers.utils.defaultAbiCoder.encode(
                        ['uint256', 'uint256'],
                        [1, 1],
                    ),
                ),
            ).to.not.be.reverted;

            await balancer.addRebalanceAmount(mtapiocaOFT0.address, 1, amount);

            ownerStateData = {
                stargateRouter: stargateRouterMock.address,
                mintFee: 0,
                mintCap: 0,
                connectedChain: 0,
                connectedChainState: false,
                balancerStateAddress: hre.ethers.constants.AddressZero,
                balancerState: false,
            };
            await mtapiocaOFT10.setOwnerState(ownerStateData);

            const data = ethers.utils.defaultAbiCoder.encode(
                ['uint256', 'uint256'],
                [1, 1],
            );

            await balancer.rebalance(
                mtapiocaOFT0.address,
                1,
                1e3,
                amount,
                data,
                {
                    value: ethers.utils.parseEther('0.1'),
                },
            );
            const balanceOft10After = await mErc20Mock.balanceOf(vault10);
            expect(balanceOft10After.eq(amount)).to.be.true;

            const balanceOft0After = await mErc20Mock.balanceOf(vault);
            expect(balanceOft0After.eq(0)).to.be.true;
        });

        it('should test checker', async () => {
            const {
                mtapiocaOFT0,
                mtapiocaOFT10,
                balancer,
                mErc20Mock,
                signer,
            } = await loadFixture(setupFixture);

            let checkData = await balancer.checker(
                mtapiocaOFT0.address,
                1,
                1e4,
            );
            expect(checkData.canExec).to.be.false;

            await expect(
                balancer.initConnectedOFT(
                    mtapiocaOFT0.address,
                    1,
                    mtapiocaOFT10.address,
                    ethers.utils.defaultAbiCoder.encode(
                        ['uint256', 'uint256'],
                        [1, 1],
                    ),
                ),
            ).to.not.be.reverted;

            checkData = await balancer.checker(mtapiocaOFT0.address, 1, 1e4);
            expect(checkData.canExec).to.be.false;

            await mErc20Mock.mintTo(signer.address, 100);
            await mErc20Mock.approve(
                mtapiocaOFT0.address,
                ethers.constants.MaxUint256,
            );
            await mtapiocaOFT0.wrap(signer.address, signer.address, 100);

            await balancer.addRebalanceAmount(mtapiocaOFT0.address, 1, 1);

            checkData = await balancer.checker(mtapiocaOFT0.address, 1, 1e4);
            expect(checkData.canExec).to.be.true;
        });

        it('should perform the call for authorized user', async () => {
            const {
                mtapiocaOFT0,
                mtapiocaOFT10,
                balancer,
                stargateRouterMock,
                mErc20Mock,
                signer,
            } = await loadFixture(setupFixture);

            const ownerStateData = {
                stargateRouter: stargateRouterMock.address,
                mintFee: 0,
                mintCap: 0,
                connectedChain: 0,
                connectedChainState: false,
                balancerStateAddress: balancer.address,
                balancerState: true,
            };
            await mtapiocaOFT10.setOwnerState(ownerStateData);
            await mtapiocaOFT0.setOwnerState(ownerStateData);

            await expect(
                balancer.initConnectedOFT(
                    mtapiocaOFT0.address,
                    1,
                    mtapiocaOFT10.address,
                    ethers.utils.defaultAbiCoder.encode(
                        ['uint256', 'uint256'],
                        [1, 1],
                    ),
                ),
            ).to.not.be.reverted;

            await mErc20Mock.mintTo(signer.address, 100);
            await mErc20Mock.approve(
                mtapiocaOFT0.address,
                ethers.constants.MaxUint256,
            );
            await mtapiocaOFT0.wrap(signer.address, signer.address, 100);

            await balancer.addRebalanceAmount(mtapiocaOFT0.address, 1, 1);

            const amount = ethers.utils.parseEther('1');
            await expect(
                balancer.rebalance(
                    mtapiocaOFT0.address,
                    1,
                    1e3,
                    1,
                    ethers.utils.toUtf8Bytes(''),
                ),
            ).to.be.reverted;

            const vault = await mtapiocaOFT0.vault();
            await time.increase(86401);
            await mErc20Mock.freeMint(amount.add(1));
            await mErc20Mock.transfer(vault, amount.add(1));

            const balance = await mErc20Mock.balanceOf(vault);
            expect(balance.eq(amount.add(101))).to.be.true;

            await expect(
                balancer.rebalance(
                    mtapiocaOFT0.address,
                    1,
                    1e3,
                    1,
                    ethers.utils.toUtf8Bytes(''),
                ),
            ).to.be.revertedWithCustomError(balancer, 'FeeAmountNotSet');

            const data = ethers.utils.defaultAbiCoder.encode(
                ['uint256', 'uint256'],
                [1, 1],
            );

            await expect(
                balancer.rebalance(mtapiocaOFT0.address, 1, 1e3, amount, data, {
                    value: ethers.utils.parseEther('0.1'),
                }),
            ).to.be.revertedWithCustomError(balancer, 'RebalanceAmountNotSet');

            await mErc20Mock.mintTo(signer.address, amount);
            await mErc20Mock.approve(
                mtapiocaOFT0.address,
                ethers.constants.MaxUint256,
            );
            await mtapiocaOFT0.wrap(signer.address, signer.address, amount);
            await balancer.addRebalanceAmount(mtapiocaOFT0.address, 1, amount);

            let checkerInfo = await balancer.checker(
                mtapiocaOFT0.address,
                1,
                1e4,
            );
            expect(checkerInfo.canExec).to.be.true;
            let oftInfo = (
                await balancer.connectedOFTs(mtapiocaOFT0.address, 1)
            ).rebalanceable;

            await expect(
                balancer.rebalance(
                    mtapiocaOFT0.address,
                    1,
                    1e3,
                    amount.add(1),
                    data,
                    {
                        value: ethers.utils.parseEther('0.1'),
                    },
                ),
            ).to.not.be.reverted;
            checkerInfo = await balancer.checker(mtapiocaOFT0.address, 1, 1e4);
            oftInfo = (await balancer.connectedOFTs(mtapiocaOFT0.address, 1))
                .rebalanceable;
            expect(checkerInfo.canExec).to.be.false;
        });

        it('should be able to register but then it should revert if not an authorized oft', async () => {
            const {
                signer,
                mtapiocaOFT0,
                mtapiocaOFT10,
                balancer,
                mErc20Mock,
                stargateRouterMock,
            } = await loadFixture(setupFixture);

            const ownerStateData = {
                stargateRouter: stargateRouterMock.address,
                mintFee: 0,
                mintCap: 0,
                connectedChain: 0,
                connectedChainState: false,
                balancerStateAddress: balancer.address,
                balancerState: true,
            };
            await mtapiocaOFT0.setOwnerState(ownerStateData);
            await mtapiocaOFT10.setOwnerState(ownerStateData);

            await expect(
                balancer.initConnectedOFT(
                    mtapiocaOFT0.address,
                    1,
                    mtapiocaOFT10.address,
                    ethers.utils.defaultAbiCoder.encode(
                        ['uint256', 'uint256'],
                        [1, 1],
                    ),
                ),
            ).to.not.be.reverted;
            const amount = ethers.utils.parseEther('1');
            await mErc20Mock.mintTo(signer.address, amount);
            await mErc20Mock.approve(
                mtapiocaOFT0.address,
                ethers.constants.MaxUint256,
            );
            await mtapiocaOFT0.wrap(signer.address, signer.address, amount);
            await balancer.addRebalanceAmount(mtapiocaOFT0.address, 1, 1);

            await expect(
                balancer.rebalance(
                    mtapiocaOFT0.address,
                    1,
                    1e3,
                    1,
                    ethers.utils.toUtf8Bytes(''),
                ),
            ).to.be.reverted;

            const vault = await mtapiocaOFT0.vault();
            await time.increase(86401);
            await mErc20Mock.freeMint(amount.add(1));
            await mErc20Mock.transfer(vault, amount.add(1));

            const balance = await mErc20Mock.balanceOf(vault);
            expect(balance.eq(amount.mul(2).add(1))).to.be.true;

            await expect(
                balancer.rebalance(
                    mtapiocaOFT0.address,
                    1,
                    1e3,
                    1,
                    ethers.utils.toUtf8Bytes(''),
                ),
            ).to.be.revertedWithCustomError(balancer, 'FeeAmountNotSet');

            const data = ethers.utils.defaultAbiCoder.encode(
                ['uint256', 'uint256'],
                [1, 1],
            );

            await expect(
                balancer.rebalance(mtapiocaOFT0.address, 1, 1e3, amount, data, {
                    value: ethers.utils.parseEther('0.1'),
                }),
            ).to.be.revertedWithCustomError(balancer, 'RebalanceAmountNotSet');

            await balancer.addRebalanceAmount(mtapiocaOFT0.address, 1, amount);

            const checkerInfo = await balancer.checker(
                mtapiocaOFT0.address,
                1,
                1e4,
            );
            expect(checkerInfo.canExec).to.be.true;

            await expect(
                balancer.rebalance(
                    mtapiocaOFT0.address,
                    1,
                    1e3,
                    amount.add(1),
                    data,
                    {
                        value: ethers.utils.parseEther('0.1'),
                    },
                ),
            ).to.not.be.reverted;
        });
    });
});
