import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { BN } from '../scripts/utils';
import { setupFixture } from './fixtures';

describe('TapiocaOFT', () => {
    it('decimals()', async () => {
        const { erc20Mock, tapiocaOFT0, tapiocaOFT10 } = await loadFixture(
            setupFixture,
        );

        expect(await tapiocaOFT0.decimals()).eq(await erc20Mock.decimals());
        expect(await tapiocaOFT10.decimals()).eq(await erc20Mock.decimals());
    });

    describe('wrap()', () => {
        it('Should fail if not on the same chain', async () => {
            const {
                signer,
                erc20Mock,
                tapiocaOFT0,
                tapiocaOFT10,
                mintAndApprove,
                dummyAmount,
            } = await loadFixture(setupFixture);

            await expect(
                tapiocaOFT10.wrap(signer.address, dummyAmount),
            ).to.be.revertedWithCustomError(tapiocaOFT10, 'TOFT__NotMainChain');

            await mintAndApprove(erc20Mock, tapiocaOFT0, signer, dummyAmount);
            await expect(tapiocaOFT0.wrap(signer.address, dummyAmount)).to.not
                .be.reverted;
        });

        it('Should fail if the fees are not paid', async () => {
            const {
                signer,
                erc20Mock,
                tapiocaOFT0,
                mintAndApprove,
                estimateFees,
                dummyAmount,
            } = await loadFixture(setupFixture);
            await mintAndApprove(
                erc20Mock,
                tapiocaOFT0,
                signer,
                BN(dummyAmount).sub(await estimateFees(dummyAmount)),
            );
            await expect(
                tapiocaOFT0.wrap(signer.address, dummyAmount),
            ).to.be.revertedWith('ERC20: insufficient allowance');
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
            await tapiocaOFT0.wrap(signer.address, dummyAmount);
            expect(await tapiocaOFT0.balanceOf(signer.address)).eq(dummyAmount);
            expect(await erc20Mock.balanceOf(signer.address)).eq(0);
        });
    });

    describe('sendFrom()', () => {
        it('Should fail if untrusted remote', async () => {
            const {
                signer,
                tapiocaWrapper,
                erc20Mock,
                tapiocaOFT0,
                tapiocaOFT10,
                mintAndApprove,
                dummyAmount,
            } = await loadFixture(setupFixture);

            // Setup
            await mintAndApprove(erc20Mock, tapiocaOFT0, signer, dummyAmount);
            await tapiocaOFT0.wrap(signer.address, dummyAmount);

            // Failure
            await expect(
                tapiocaOFT0.sendFrom(
                    signer.address,
                    1,
                    signer.address,
                    1,
                    signer.address,
                    signer.address,
                    ethers.utils.arrayify(0),
                ),
            ).to.be.revertedWith(
                'LzApp: destination chain is not a trusted source',
            );

            // Set trusted remotes
            await tapiocaWrapper.executeTOFT(
                tapiocaOFT0.address,
                tapiocaOFT0.interface.encodeFunctionData('setTrustedRemote', [
                    1,
                    tapiocaOFT10.address,
                ]),
                true,
            );
            await tapiocaWrapper.executeTOFT(
                tapiocaOFT10.address,
                tapiocaOFT10.interface.encodeFunctionData('setTrustedRemote', [
                    0,
                    tapiocaOFT0.address,
                ]),
                true,
            );

            // Success
            await expect(
                tapiocaOFT0.sendFrom(
                    signer.address,
                    1,
                    signer.address,
                    1,
                    signer.address,
                    signer.address,
                    ethers.utils.arrayify(0),
                ),
            ).to.not.be.reverted;
        });
    });

    describe('harvestFees', () => {
        it('Should be called only on MainChain', async () => {
            const {
                signer,
                erc20Mock,
                tapiocaOFT0,
                tapiocaOFT10,
                mintAndApprove,
                estimateFees,
                dummyAmount,
            } = await loadFixture(setupFixture);
            await mintAndApprove(erc20Mock, tapiocaOFT0, signer, dummyAmount);
            await tapiocaOFT0.wrap(signer.address, dummyAmount);

            const fees = await estimateFees(dummyAmount);
            expect(fees.gt(0)).to.be.true;

            await expect(tapiocaOFT0.harvestFees()).to.emit(
                tapiocaOFT0,
                'Harvest',
            );

            await expect(
                tapiocaOFT10.harvestFees(),
            ).to.be.revertedWithCustomError(tapiocaOFT10, 'TOFT__NotMainChain');
        });

        it('Should withdraw the fees and update the total fee balance', async () => {
            const {
                signer,
                tapiocaWrapper,
                erc20Mock,
                tapiocaOFT0,
                mintAndApprove,
                dummyAmount,
            } = await loadFixture(setupFixture);
            await mintAndApprove(erc20Mock, tapiocaOFT0, signer, dummyAmount);
            await tapiocaOFT0.wrap(signer.address, dummyAmount);

            const feesBefore = await tapiocaOFT0.totalFees();

            await tapiocaOFT0.harvestFees();

            expect(await erc20Mock.balanceOf(tapiocaWrapper.address)).eq(
                feesBefore,
            );

            const feesAfter = await tapiocaOFT0.totalFees();
            expect(feesAfter).eq(0);
        });
    });
});
