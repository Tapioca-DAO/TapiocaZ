import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import { BN } from '../scripts/utils';
import { setupFixture } from './fixtures';

//should be executed on mainnet fork
describe('Balancer', () => {
    describe('connectedOFTs', () => {
        it('should fail for unauthorized user', async () => {
            const { randomUser, mtapiocaOFT0, balancer } = await loadFixture(
                setupFixture,
            );

            expect(randomUser.address).to.not.eq(ethers.constants.AddressZero);

            const path = hre.ethers.utils.solidityPack(
                ['address', 'address'],
                [mtapiocaOFT0.address, mtapiocaOFT0.address],
            );
            const encodedTX = (
                await hre.ethers.getContractFactory('TapiocaOFT')
            ).interface.encodeFunctionData('setTrustedRemote', [1, path]);

            const tWrapper = await ethers.getContractAt(
                'TapiocaWrapper',
                await mtapiocaOFT0.tapiocaWrapper(),
            );
            await tWrapper.executeTOFT(mtapiocaOFT0.address, encodedTX, true);

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
            const { mtapiocaOFT0, balancer, tapiocaWrapper_0 } =
                await loadFixture(setupFixture);

            const path = hre.ethers.utils.solidityPack(
                ['address', 'address'],
                [mtapiocaOFT0.address, mtapiocaOFT0.address],
            );
            const encodedTX = (
                await hre.ethers.getContractFactory('TapiocaOFT')
            ).interface.encodeFunctionData('setTrustedRemote', [1, path]);

            const tWrapper = await ethers.getContractAt(
                'TapiocaWrapper',
                await mtapiocaOFT0.tapiocaWrapper(),
            );
            await tWrapper.executeTOFT(mtapiocaOFT0.address, encodedTX, true);

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

            const path = hre.ethers.utils.solidityPack(
                ['address', 'address'],
                [mtapiocaOFT0.address, mtapiocaOFT0.address],
            );
            const encodedTX = (
                await hre.ethers.getContractFactory('TapiocaOFT')
            ).interface.encodeFunctionData('setTrustedRemote', [1, path]);

            const tWrapper = await ethers.getContractAt(
                'TapiocaWrapper',
                await mtapiocaOFT0.tapiocaWrapper(),
            );
            await tWrapper.executeTOFT(mtapiocaOFT0.address, encodedTX, true);

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
            ).to.be.revertedWith('UNAUTHORIZED');

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
                signer,
                mtapiocaOFT0,
                mtapiocaOFT10,
                balancer,
                tapiocaWrapper_0,
                mErc20Mock,
            } = await loadFixture(setupFixture);

            const path = hre.ethers.utils.solidityPack(
                ['address', 'address'],
                [mtapiocaOFT10.address, mtapiocaOFT0.address],
            );
            const encodedTX = (
                await hre.ethers.getContractFactory('TapiocaOFT')
            ).interface.encodeFunctionData('setTrustedRemote', [1, path]);

            const tWrapper = await ethers.getContractAt(
                'TapiocaWrapper',
                await mtapiocaOFT0.tapiocaWrapper(),
            );
            await tWrapper.executeTOFT(mtapiocaOFT0.address, encodedTX, true);

            const txData = mtapiocaOFT0.interface.encodeFunctionData(
                'updateBalancerState',
                [balancer.address, true],
            );
            await expect(
                tapiocaWrapper_0.executeTOFT(
                    mtapiocaOFT0.address,
                    txData,
                    true,
                ),
            ).to.not.be.reverted;

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
            await mErc20Mock.mint(signer.address, amount);
            await mErc20Mock.transfer(mtapiocaOFT0.address, amount);

            const balance = await mErc20Mock.balanceOf(mtapiocaOFT0.address);
            expect(balance.eq(amount)).to.be.true;

            const balanceOft10Before = await mErc20Mock.balanceOf(
                mtapiocaOFT10.address,
            );
            expect(balanceOft10Before.eq(0)).to.be.true;

            await balancer.addRebalanceAmount(mtapiocaOFT0.address, 1, amount);

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
            const balanceOft10After = await mErc20Mock.balanceOf(
                mtapiocaOFT10.address,
            );
            expect(balanceOft10After.eq(amount)).to.be.true;

            const balanceOft0After = await mErc20Mock.balanceOf(
                mtapiocaOFT0.address,
            );
            expect(balanceOft0After.eq(0)).to.be.true;
        });

        it('should test checker', async () => {
            const { mtapiocaOFT0, mtapiocaOFT10, balancer } = await loadFixture(
                setupFixture,
            );

            const path = hre.ethers.utils.solidityPack(
                ['address', 'address'],
                [mtapiocaOFT10.address, mtapiocaOFT0.address],
            );
            const encodedTX = (
                await hre.ethers.getContractFactory('TapiocaOFT')
            ).interface.encodeFunctionData('setTrustedRemote', [1, path]);

            const tWrapper = await ethers.getContractAt(
                'TapiocaWrapper',
                await mtapiocaOFT0.tapiocaWrapper(),
            );
            await tWrapper.executeTOFT(mtapiocaOFT0.address, encodedTX, true);

            let checkData = await balancer.checker(mtapiocaOFT0.address, 1);
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

            checkData = await balancer.checker(mtapiocaOFT0.address, 1);
            expect(checkData.canExec).to.be.false;

            await balancer.addRebalanceAmount(mtapiocaOFT0.address, 1, 1);

            checkData = await balancer.checker(mtapiocaOFT0.address, 1);
            expect(checkData.canExec).to.be.true;
        });

        it('should perform the call for authorized user', async () => {
            const {
                signer,
                mtapiocaOFT0,
                mtapiocaOFT10,
                balancer,
                tapiocaWrapper_0,
                mErc20Mock,
            } = await loadFixture(setupFixture);

            const path = hre.ethers.utils.solidityPack(
                ['address', 'address'],
                [mtapiocaOFT10.address, mtapiocaOFT0.address],
            );
            const encodedTX = (
                await hre.ethers.getContractFactory('TapiocaOFT')
            ).interface.encodeFunctionData('setTrustedRemote', [1, path]);

            const tWrapper = await ethers.getContractAt(
                'TapiocaWrapper',
                await mtapiocaOFT0.tapiocaWrapper(),
            );
            await tWrapper.executeTOFT(mtapiocaOFT0.address, encodedTX, true);

            const txData = mtapiocaOFT0.interface.encodeFunctionData(
                'updateBalancerState',
                [balancer.address, true],
            );
            await expect(
                tapiocaWrapper_0.executeTOFT(
                    mtapiocaOFT0.address,
                    txData,
                    true,
                ),
            ).to.not.be.reverted;

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
            ).to.be.revertedWith('ERC20: transfer amount exceeds balance');

            await mErc20Mock.mint(signer.address, amount.add(1));
            await mErc20Mock.transfer(mtapiocaOFT0.address, amount.add(1));

            const balance = await mErc20Mock.balanceOf(mtapiocaOFT0.address);
            expect(balance.eq(amount.add(1))).to.be.true;

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

            let checkerInfo = await balancer.checker(mtapiocaOFT0.address, 1);
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
            checkerInfo = await balancer.checker(mtapiocaOFT0.address, 1);
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
                tapiocaWrapper_0,
                mErc20Mock,
            } = await loadFixture(setupFixture);

            let path = hre.ethers.utils.solidityPack(
                ['address', 'address'],
                [mtapiocaOFT10.address, mtapiocaOFT0.address],
            );
            let encodedTX = (
                await hre.ethers.getContractFactory('TapiocaOFT')
            ).interface.encodeFunctionData('setTrustedRemote', [1, path]);

            const tWrapper = await ethers.getContractAt(
                'TapiocaWrapper',
                await mtapiocaOFT0.tapiocaWrapper(),
            );
            await tWrapper.executeTOFT(mtapiocaOFT0.address, encodedTX, true);

            const txData = mtapiocaOFT0.interface.encodeFunctionData(
                'updateBalancerState',
                [balancer.address, true],
            );
            await expect(
                tapiocaWrapper_0.executeTOFT(
                    mtapiocaOFT0.address,
                    txData,
                    true,
                ),
            ).to.not.be.reverted;

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
            ).to.be.revertedWith('ERC20: transfer amount exceeds balance');

            await mErc20Mock.mint(signer.address, amount.add(1));
            await mErc20Mock.transfer(mtapiocaOFT0.address, amount.add(1));

            const balance = await mErc20Mock.balanceOf(mtapiocaOFT0.address);
            expect(balance.eq(amount.add(1))).to.be.true;

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

            const checkerInfo = await balancer.checker(mtapiocaOFT0.address, 1);
            expect(checkerInfo.canExec).to.be.true;

            path = hre.ethers.utils.solidityPack(
                ['address', 'address'],
                [mtapiocaOFT0.address, mtapiocaOFT0.address],
            );
            encodedTX = (
                await hre.ethers.getContractFactory('TapiocaOFT')
            ).interface.encodeFunctionData('setTrustedRemote', [1, path]);

            await tWrapper.executeTOFT(mtapiocaOFT0.address, encodedTX, true);
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
            ).to.be.revertedWithCustomError(balancer, 'DestinationOftNotValid');
        });
    });
});
