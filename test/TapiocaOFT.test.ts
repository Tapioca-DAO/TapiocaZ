import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import { setupFixture } from './fixtures';

describe('TapiocaOFT', () => {
    it('simulate deploy', async () => {
        const erc20Mock = await (
            await hre.ethers.getContractFactory('ERC20Mock')
        ).deploy('erc20Mock', 'MOCK');

        const lzEndpoint = await (
            await (await ethers.getContractFactory('LZEndpointMock')).deploy(1)
        ).deployed();

        const yieldBox = await (
            await (await ethers.getContractFactory('YieldBoxMock')).deploy()
        ).deployed();

        await (
            await hre.ethers.getContractFactory('TapiocaOFT')
        ).deploy(
            lzEndpoint.address,
            false,
            erc20Mock.address,
            yieldBox.address,
            'test',
            'tt',
            18,
            1,
        );
    });
    it('decimals()', async () => {
        const { erc20Mock, tapiocaOFT0, tapiocaOFT10 } = await loadFixture(
            setupFixture,
        );

        expect(await tapiocaOFT0.decimals()).eq(await erc20Mock.decimals());
        expect(await tapiocaOFT10.decimals()).eq(await erc20Mock.decimals());
    });

    describe('wrap()', () => {
        it('Should fail if not on the same chain', async () => {
            const { signer, tapiocaOFT10, dummyAmount } = await loadFixture(
                setupFixture,
            );

            await expect(
                tapiocaOFT10.wrap(signer.address, signer.address, dummyAmount),
            ).to.be.revertedWithCustomError(tapiocaOFT10, 'TOFT__NotHostChain');
        });

        it('Should wrap and give a 1:1 ratio amount of tokens', async () => {
            const {
                signer,
                erc20Mock,
                tapiocaOFT0,
                mintAndApprove,
                dummyAmount,
            } = await loadFixture(setupFixture);

            await mintAndApprove(erc20Mock, tapiocaOFT0, signer, dummyAmount);

            const balTOFTSignerBefore = await tapiocaOFT0.balanceOf(
                signer.address,
            );
            const balERC20ContractBefore = await erc20Mock.balanceOf(
                tapiocaOFT0.address,
            );

            await tapiocaOFT0.wrap(signer.address, signer.address, dummyAmount);

            const balTOFTSignerAfter = await tapiocaOFT0.balanceOf(
                signer.address,
            );
            const balERC20ContractAfter = await erc20Mock.balanceOf(
                tapiocaOFT0.address,
            );

            expect(balTOFTSignerAfter).eq(balTOFTSignerBefore.add(dummyAmount));
            expect(balERC20ContractAfter).eq(
                balERC20ContractBefore.add(dummyAmount),
            );
        });
    });

    describe('unwrap()', () => {
        it('Should fail if not on the same chain', async () => {
            const { signer, tapiocaOFT10, dummyAmount } = await loadFixture(
                setupFixture,
            );

            await expect(
                tapiocaOFT10.unwrap(signer.address, dummyAmount),
            ).to.be.revertedWithCustomError(tapiocaOFT10, 'TOFT__NotHostChain');
        });
        it('Should unwrap and give a 1:1 ratio amount of tokens', async () => {
            const {
                signer,
                erc20Mock,
                tapiocaOFT0,
                mintAndApprove,
                dummyAmount,
            } = await loadFixture(setupFixture);

            await mintAndApprove(erc20Mock, tapiocaOFT0, signer, dummyAmount);
            await tapiocaOFT0.wrap(signer.address, signer.address, dummyAmount);

            const balTOFTSignerBefore = await tapiocaOFT0.balanceOf(
                signer.address,
            );
            const balERC20SignerBefore = await erc20Mock.balanceOf(
                signer.address,
            );
            const balERC20ContractBefore = await erc20Mock.balanceOf(
                tapiocaOFT0.address,
            );

            await expect(tapiocaOFT0.unwrap(signer.address, dummyAmount)).to.not
                .be.reverted;

            const balTOFTSignerAfter = await tapiocaOFT0.balanceOf(
                signer.address,
            );
            const balERC20SignerAfter = await erc20Mock.balanceOf(
                signer.address,
            );
            const balERC20ContractAfter = await erc20Mock.balanceOf(
                tapiocaOFT0.address,
            );

            expect(balTOFTSignerAfter).eq(balTOFTSignerBefore.sub(dummyAmount));
            expect(balERC20SignerAfter).eq(
                balERC20SignerBefore.add(dummyAmount),
            );
            expect(balERC20ContractAfter).eq(
                balERC20ContractBefore.sub(dummyAmount),
            );
        });
    });

    describe('sendFrom()', () => {
        it('Should fail if untrusted remote', async () => {
            const {
                signer,
                tapiocaWrapper_0,
                tapiocaWrapper_10,
                erc20Mock,
                tapiocaOFT0,
                tapiocaOFT10,
                mintAndApprove,
                bigDummyAmount,
            } = await loadFixture(setupFixture);

            // Setup
            await mintAndApprove(
                erc20Mock,
                tapiocaOFT0,
                signer,
                bigDummyAmount,
            );
            await tapiocaOFT0.wrap(
                signer.address,
                signer.address,
                bigDummyAmount,
            );

            // Failure
            await expect(
                tapiocaOFT0.sendFrom(
                    signer.address,
                    1,
                    ethers.utils.defaultAbiCoder.encode(
                        ['address'],
                        [signer.address],
                    ),
                    bigDummyAmount,
                    {
                        refundAddress: signer.address,
                        zroPaymentAddress: ethers.constants.AddressZero,
                        adapterParams: '0x',
                    },
                ),
            ).to.be.revertedWith(
                'LzApp: destination chain is not a trusted source',
            );

            // Set trusted remotes
            await tapiocaWrapper_0.executeTOFT(
                tapiocaOFT0.address,
                tapiocaOFT0.interface.encodeFunctionData('setTrustedRemote', [
                    1,
                    ethers.utils.solidityPack(
                        ['address', 'address'],
                        [tapiocaOFT10.address, tapiocaOFT0.address],
                    ),
                ]),
                true,
            );
            await tapiocaWrapper_10.executeTOFT(
                tapiocaOFT10.address,
                tapiocaOFT10.interface.encodeFunctionData('setTrustedRemote', [
                    0,
                    ethers.utils.solidityPack(
                        ['address', 'address'],
                        [tapiocaOFT0.address, tapiocaOFT10.address],
                    ),
                ]),
                true,
            );

            // Success
            await expect(
                tapiocaOFT0.sendFrom(
                    signer.address,
                    1,
                    ethers.utils.defaultAbiCoder.encode(
                        ['address'],
                        [signer.address],
                    ),
                    bigDummyAmount,
                    {
                        refundAddress: signer.address,
                        zroPaymentAddress: ethers.constants.AddressZero,
                        adapterParams: '0x',
                    },
                    {
                        value: ethers.utils.parseEther('0.02'),
                    },
                ),
            ).to.not.be.reverted;
        });
    });

    describe('sendToYieldBox()', () => {
        it('should wrap and deposit to YB on another chain', async () => {
            const {
                signer,
                tapiocaWrapper_0,
                tapiocaWrapper_10,
                erc20Mock,
                tapiocaOFT0,
                tapiocaOFT10,
                mintAndApprove,
                bigDummyAmount,
                YieldBox_0,
                YieldBox_10,
            } = await loadFixture(setupFixture);

            // Setup
            await mintAndApprove(
                erc20Mock,
                tapiocaOFT0,
                signer,
                bigDummyAmount,
            );

            // Set trusted remotes
            await tapiocaWrapper_0.executeTOFT(
                tapiocaOFT0.address,
                tapiocaOFT0.interface.encodeFunctionData('setTrustedRemote', [
                    10,
                    ethers.utils.solidityPack(
                        ['address', 'address'],
                        [tapiocaOFT10.address, tapiocaOFT0.address],
                    ),
                ]),
                true,
            );
            await tapiocaWrapper_10.executeTOFT(
                tapiocaOFT10.address,
                tapiocaOFT10.interface.encodeFunctionData('setTrustedRemote', [
                    0,
                    ethers.utils.solidityPack(
                        ['address', 'address'],
                        [tapiocaOFT0.address, tapiocaOFT10.address],
                    ),
                ]),
                true,
            );

            // Success

            await YieldBox_0.addAsset(1, tapiocaOFT0.address);
            await YieldBox_10.addAsset(1, tapiocaOFT10.address);

            const dstChainId = await tapiocaOFT10.getLzChainId();

            const signerToftBalanceBeforeDeposit = await tapiocaOFT0.balanceOf(
                signer.address,
            );
            expect(signerToftBalanceBeforeDeposit.eq(0)).to.be.true;
            const toDeposit = bigDummyAmount;
            await tapiocaOFT0.connect(signer).sendToYB(
                signer.address,
                signer.address,
                toDeposit,
                1, //asset id
                dstChainId, //dst chain Id
                {
                    extraGasLimit: '800000',
                    zroPaymentAddress: ethers.constants.AddressZero,
                    strategyDeposit: false,
                    wrap: true,
                },
                {
                    value: ethers.utils.parseEther('0.021'),
                },
            );

            let ybBalance = await tapiocaOFT10.balanceOf(YieldBox_10.address);
            expect(ybBalance.gt(0)).to.be.true;

            const ybBalanceOfSigner = await YieldBox_10.balances(
                signer.address,
            );
            expect(ybBalanceOfSigner.eq(toDeposit)).to.be.true;

            const airdropAdapterParams = ethers.utils.solidityPack(
                ['uint16', 'uint', 'uint', 'address'],
                [
                    2,
                    800000,
                    ethers.utils.parseEther('0.015'),
                    tapiocaOFT10.address,
                ],
            );
            const signerBalanceBeforeRetrieve =
                await ethers.provider.getBalance(signer.address);
            await tapiocaOFT0.retrieveFromYB(
                toDeposit,
                1,
                dstChainId,
                ethers.constants.AddressZero,
                airdropAdapterParams,
                false,
                {
                    value: ethers.utils.parseEther('0.05'),
                },
            );
            ybBalance = await tapiocaOFT10.balanceOf(YieldBox_10.address);
            expect(ybBalance.eq(0)).to.be.true;

            const signerBalanceAfterRetrieve = await ethers.provider.getBalance(
                signer.address,
            );

            expect(
                signerBalanceAfterRetrieve
                    .add(ethers.utils.parseEther('0.05'))
                    .gte(signerBalanceBeforeRetrieve),
            ).to.be.true;

            const signerToftBalanceAfterWithdraw = await tapiocaOFT0.balanceOf(
                signer.address,
            );
            expect(signerToftBalanceAfterWithdraw.eq(toDeposit)).to.be.true;
        });

        it('should deposit to YB on another chain and then withdraw back', async () => {
            const {
                signer,
                tapiocaWrapper_0,
                tapiocaWrapper_10,
                erc20Mock,
                tapiocaOFT0,
                tapiocaOFT10,
                mintAndApprove,
                bigDummyAmount,
                YieldBox_0,
                YieldBox_10,
            } = await loadFixture(setupFixture);

            // Setup
            await mintAndApprove(
                erc20Mock,
                tapiocaOFT0,
                signer,
                bigDummyAmount,
            );
            await tapiocaOFT0.wrap(
                signer.address,
                signer.address,
                bigDummyAmount,
            );

            // Set trusted remotes
            await tapiocaWrapper_0.executeTOFT(
                tapiocaOFT0.address,
                tapiocaOFT0.interface.encodeFunctionData('setTrustedRemote', [
                    10,
                    ethers.utils.solidityPack(
                        ['address', 'address'],
                        [tapiocaOFT10.address, tapiocaOFT0.address],
                    ),
                ]),
                true,
            );
            await tapiocaWrapper_10.executeTOFT(
                tapiocaOFT10.address,
                tapiocaOFT10.interface.encodeFunctionData('setTrustedRemote', [
                    0,
                    ethers.utils.solidityPack(
                        ['address', 'address'],
                        [tapiocaOFT0.address, tapiocaOFT10.address],
                    ),
                ]),
                true,
            );

            // Success
            await expect(
                tapiocaOFT0.sendFrom(
                    signer.address,
                    10,
                    ethers.utils.defaultAbiCoder.encode(
                        ['address'],
                        [signer.address],
                    ),
                    bigDummyAmount,
                    {
                        refundAddress: signer.address,
                        zroPaymentAddress: ethers.constants.AddressZero,
                        adapterParams: '0x',
                    },
                    {
                        value: ethers.utils.parseEther('0.2'),
                    },
                ),
            ).to.not.be.reverted;

            const srcYieldBox = await tapiocaOFT0.yieldBox();
            expect(srcYieldBox.toLowerCase()).eq(
                YieldBox_0.address.toLowerCase(),
            );
            const dstYieldBox = await tapiocaOFT10.yieldBox();
            expect(dstYieldBox.toLowerCase()).eq(
                YieldBox_10.address.toLowerCase(),
            );

            await YieldBox_0.addAsset(1, tapiocaOFT0.address);
            await YieldBox_10.addAsset(1, tapiocaOFT10.address);

            const dstChainId = await tapiocaOFT10.getLzChainId();

            const signerBalanceBeforeDeposit = await ethers.provider.getBalance(
                signer.address,
            );

            await mintAndApprove(
                erc20Mock,
                tapiocaOFT0,
                signer,
                bigDummyAmount,
            );
            await tapiocaOFT0.wrap(
                signer.address,
                signer.address,
                bigDummyAmount,
            );
            const signerToftBalanceBeforeDeposit = await tapiocaOFT0.balanceOf(
                signer.address,
            );
            const toDeposit = bigDummyAmount;
            await tapiocaOFT0.sendToYB(
                signer.address,
                signer.address,
                toDeposit,
                1, //asset id
                dstChainId, //dst chain Id
                {
                    extraGasLimit: '800000',
                    zroPaymentAddress: ethers.constants.AddressZero,
                    strategyDeposit: false,
                    wrap: false,
                },
                {
                    value: ethers.utils.parseEther('0.021'),
                },
            );
            const signerBalanceAfterDeposit = await ethers.provider.getBalance(
                signer.address,
            );
            expect(
                signerBalanceAfterDeposit
                    .add(ethers.utils.parseEther('0.021'))
                    .gte(signerBalanceBeforeDeposit),
            ).to.be.true;

            let ybBalance = await tapiocaOFT10.balanceOf(YieldBox_10.address);
            expect(ybBalance.gt(0)).to.be.true;

            const ybBalanceOfSigner = await YieldBox_10.balances(
                signer.address,
            );
            expect(ybBalanceOfSigner.gt(0)).to.be.true;

            const signerToftBalanceAfterDeposit = await tapiocaOFT0.balanceOf(
                signer.address,
            );
            expect(signerToftBalanceAfterDeposit.add(toDeposit)).to.eq(
                signerToftBalanceBeforeDeposit,
            );

            const signerToftBalanceBeforeWithdraw = await tapiocaOFT0.balanceOf(
                signer.address,
            );

            const airdropAdapterParams = ethers.utils.solidityPack(
                ['uint16', 'uint', 'uint', 'address'],
                [
                    2,
                    800000,
                    ethers.utils.parseEther('0.015'),
                    tapiocaOFT10.address,
                ],
            );
            const signerBalanceBeforeRetrieve =
                await ethers.provider.getBalance(signer.address);
            await tapiocaOFT0.retrieveFromYB(
                toDeposit,
                1,
                dstChainId,
                ethers.constants.AddressZero,
                airdropAdapterParams,
                false,
                {
                    value: ethers.utils.parseEther('0.05'),
                },
            );
            ybBalance = await tapiocaOFT10.balanceOf(YieldBox_10.address);
            expect(ybBalance.eq(0)).to.be.true;

            const signerBalanceAfterRetrieve = await ethers.provider.getBalance(
                signer.address,
            );

            expect(
                signerBalanceAfterRetrieve
                    .add(ethers.utils.parseEther('0.05'))
                    .gte(signerBalanceBeforeRetrieve),
            ).to.be.true;

            const signerToftBalanceAfterWithdraw = await tapiocaOFT0.balanceOf(
                signer.address,
            );
            expect(signerToftBalanceBeforeWithdraw.add(toDeposit)).to.eq(
                signerToftBalanceAfterWithdraw,
            );
        });

        it('should deposit to YB on another chain and then withdraw back - strategy', async () => {
            const {
                signer,
                tapiocaWrapper_0,
                tapiocaWrapper_10,
                erc20Mock,
                tapiocaOFT0,
                tapiocaOFT10,
                mintAndApprove,
                bigDummyAmount,
                YieldBox_0,
                YieldBox_10,
            } = await loadFixture(setupFixture);

            // Setup
            await mintAndApprove(
                erc20Mock,
                tapiocaOFT0,
                signer,
                bigDummyAmount,
            );
            await tapiocaOFT0.wrap(
                signer.address,
                signer.address,
                bigDummyAmount,
            );

            // Set trusted remotes
            await tapiocaWrapper_0.executeTOFT(
                tapiocaOFT0.address,
                tapiocaOFT0.interface.encodeFunctionData('setTrustedRemote', [
                    10,
                    ethers.utils.solidityPack(
                        ['address', 'address'],
                        [tapiocaOFT10.address, tapiocaOFT0.address],
                    ),
                ]),
                true,
            );
            await tapiocaWrapper_10.executeTOFT(
                tapiocaOFT10.address,
                tapiocaOFT10.interface.encodeFunctionData('setTrustedRemote', [
                    0,
                    ethers.utils.solidityPack(
                        ['address', 'address'],
                        [tapiocaOFT0.address, tapiocaOFT10.address],
                    ),
                ]),
                true,
            );

            await YieldBox_0.addAsset(1, tapiocaOFT0.address);
            await YieldBox_10.addAsset(1, tapiocaOFT10.address);

            const dstChainId = await tapiocaOFT10.getLzChainId();

            const toDeposit = bigDummyAmount;
            await tapiocaOFT0.sendToYB(
                signer.address,
                signer.address,
                toDeposit,
                1, //asset id
                dstChainId, //dst chain Id
                {
                    extraGasLimit: '800000',
                    zroPaymentAddress: ethers.constants.AddressZero,
                    strategyDeposit: true,
                    wrap: false,
                },
                {
                    value: ethers.utils.parseEther('10'),
                },
            );

            let ybBalance = await tapiocaOFT10.balanceOf(YieldBox_10.address);
            expect(ybBalance.gt(0)).to.be.true;

            const ybBalanceOfOFT = await YieldBox_10.balances(
                tapiocaOFT10.address,
            );
            expect(ybBalanceOfOFT.gt(0)).to.be.true;

            const signerToftBalanceBeforeWithdraw = await tapiocaOFT0.balanceOf(
                signer.address,
            );

            const airdropAdapterParams = ethers.utils.solidityPack(
                ['uint16', 'uint', 'uint', 'address'],
                [
                    2,
                    800000,
                    ethers.utils.parseEther('0.015'),
                    tapiocaOFT10.address,
                ],
            );

            await tapiocaOFT0.retrieveFromYB(
                toDeposit,
                1,
                dstChainId,
                ethers.constants.AddressZero,
                airdropAdapterParams,
                true,
                {
                    value: ethers.utils.parseEther('0.05'),
                },
            );

            ybBalance = await tapiocaOFT10.balanceOf(YieldBox_10.address);
            expect(ybBalance.eq(0)).to.be.true;

            const signerToftBalanceAfterWithdraw = await tapiocaOFT0.balanceOf(
                signer.address,
            );
            expect(signerToftBalanceBeforeWithdraw.add(toDeposit)).to.eq(
                signerToftBalanceAfterWithdraw,
            );
        });
    });
});
