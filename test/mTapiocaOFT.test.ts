import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import { BN } from '../scripts/utils';
import { setupFixture } from './fixtures';

describe('mTapiocaOFT', () => {
    describe('extractUnderlying()', () => {
        it('should fail for unknown balance', async () => {
            const { signer, mtapiocaOFT0, dummyAmount, tapiocaWrapper_0 } =
                await loadFixture(setupFixture);

            let balancerStatus = await mtapiocaOFT0.balancers(signer.address);
            expect(balancerStatus).to.be.false;

            await expect(mtapiocaOFT0.extractUnderlying(1)).to.be.revertedWith(
                'TapiocaOFT: not authorized',
            );

            const txData = mtapiocaOFT0.interface.encodeFunctionData(
                'updateBalancerState',
                [signer.address, true],
            );
            await expect(
                tapiocaWrapper_0.executeTOFT(
                    mtapiocaOFT0.address,
                    txData,
                    true,
                ),
            ).to.not.be.reverted;

            balancerStatus = await mtapiocaOFT0.balancers(signer.address);
            expect(balancerStatus).to.be.true;

            await expect(
                mtapiocaOFT0.extractUnderlying(1),
            ).to.not.be.revertedWith('TapiocaOFT: not authorized');
        });
    });

    describe('wrap()', () => {
        it('Should fail if not on the same chain', async () => {
            const {
                signer,
                mtapiocaOFT0,
                mtapiocaOFT10,
                dummyAmount,
                mErc20Mock,
                mintAndApprove,
                estimateFees,
            } = await loadFixture(setupFixture);

            await mintAndApprove(
                mErc20Mock,
                mtapiocaOFT0,
                signer,
                BN(dummyAmount),
            );
            await expect(
                mtapiocaOFT10.wrap(signer.address, dummyAmount),
            ).to.be.revertedWithCustomError(mtapiocaOFT0, 'TOFT__NotHostChain');
        });

        it('Should fail if the fees are not paid', async () => {
            const {
                signer,
                mErc20Mock,
                mtapiocaOFT0,
                mintAndApprove,
                estimateFees,
                dummyAmount,
            } = await loadFixture(setupFixture);
            await mintAndApprove(
                mErc20Mock,
                mtapiocaOFT0,
                signer,
                BN(dummyAmount).sub(await estimateFees(dummyAmount)),
            );
            await expect(
                mtapiocaOFT0.wrap(signer.address, dummyAmount),
            ).to.be.revertedWith('ERC20: insufficient allowance');
        });

        it('Should wrap and give a 1:1 ratio amount of tokens without fees', async () => {
            const {
                signer,
                mErc20Mock,
                mtapiocaOFT0,
                tapiocaWrapper_0,
                mintAndApprove,
                dummyAmount,
            } = await loadFixture(setupFixture);
            await tapiocaWrapper_0.setMngmtFee(0);

            await mintAndApprove(mErc20Mock, mtapiocaOFT0, signer, dummyAmount);

            const balTOFTSignerBefore = await mtapiocaOFT0.balanceOf(
                signer.address,
            );
            const balERC20ContractBefore = await mErc20Mock.balanceOf(
                mtapiocaOFT0.address,
            );

            await mtapiocaOFT0.wrap(signer.address, dummyAmount);

            const balTOFTSignerAfter = await mtapiocaOFT0.balanceOf(
                signer.address,
            );
            const balERC20ContractAfter = await mErc20Mock.balanceOf(
                mtapiocaOFT0.address,
            );

            expect(balTOFTSignerAfter).eq(balTOFTSignerBefore.add(dummyAmount));
            expect(balERC20ContractAfter).eq(
                balERC20ContractBefore.add(dummyAmount),
            );
        });

        it('Should wrap and give a 1:1 ratio amount of tokens with fees', async () => {
            const {
                signer,
                mErc20Mock,
                mtapiocaOFT0,
                mintAndApprove,
                dummyAmount,
                estimateFees,
            } = await loadFixture(setupFixture);

            const fees = await estimateFees(dummyAmount);
            const feesBefore = await mtapiocaOFT0.totalFees();

            await mintAndApprove(mErc20Mock, mtapiocaOFT0, signer, dummyAmount);

            const balTOFTSignerBefore = await mtapiocaOFT0.balanceOf(
                signer.address,
            );
            const balERC20ContractBefore = await mErc20Mock.balanceOf(
                mtapiocaOFT0.address,
            );

            await mtapiocaOFT0.wrap(signer.address, dummyAmount);

            const balTOFTSignerAfter = await mtapiocaOFT0.balanceOf(
                signer.address,
            );
            const balERC20ContractAfter = await mErc20Mock.balanceOf(
                mtapiocaOFT0.address,
            );

            expect(balTOFTSignerAfter).eq(balTOFTSignerBefore.add(dummyAmount));
            expect(balERC20ContractAfter).eq(
                balERC20ContractBefore.add(dummyAmount.add(fees)),
            );

            const feesAfter = await mtapiocaOFT0.totalFees();
            expect(feesAfter.sub(feesBefore)).eq(fees);
        });

        it('Should be able to extract tokens', async () => {
            const {
                signer,
                mErc20Mock,
                mtapiocaOFT0,
                tapiocaWrapper_0,
                mintAndApprove,
                dummyAmount,
                estimateFees,
            } = await loadFixture(setupFixture);

            const fees = await estimateFees(dummyAmount);
            const feesBefore = await mtapiocaOFT0.totalFees();

            await mintAndApprove(mErc20Mock, mtapiocaOFT0, signer, dummyAmount);

            await mtapiocaOFT0.wrap(signer.address, dummyAmount);

            const signerBalanceBefore = await mErc20Mock.balanceOf(
                signer.address,
            );
            expect(signerBalanceBefore.eq(0)).to.be.true;

            await expect(
                mtapiocaOFT0.extractUnderlying(dummyAmount),
            ).to.be.revertedWith('TapiocaOFT: not authorized');

            const txData = mtapiocaOFT0.interface.encodeFunctionData(
                'updateBalancerState',
                [signer.address, true],
            );
            await expect(
                tapiocaWrapper_0.executeTOFT(
                    mtapiocaOFT0.address,
                    txData,
                    true,
                ),
            ).to.not.be.reverted;

            await expect(mtapiocaOFT0.extractUnderlying(dummyAmount)).to.not.be
                .reverted;

            const signerBalanceAfter = await mErc20Mock.balanceOf(
                signer.address,
            );
            expect(signerBalanceAfter.eq(dummyAmount)).to.be.true;
        });
    });

    describe('unwrap()', () => {
        it('Should fail if not on the same chain', async () => {
            const {
                signer,
                mtapiocaOFT0,
                mtapiocaOFT10,
                tapiocaWrapper_10,
                dummyAmount,
            } = await loadFixture(setupFixture);

            await expect(
                mtapiocaOFT10.unwrap(signer.address, dummyAmount),
            ).to.be.revertedWithCustomError(
                mtapiocaOFT10,
                'TOFT_NotAllowedChain',
            );

            const otherChainId = await mtapiocaOFT0.hostChainID();
            const txData = mtapiocaOFT10.interface.encodeFunctionData(
                'updateConnectedChain',
                [otherChainId, true],
            );
            await expect(
                tapiocaWrapper_10.executeTOFT(
                    mtapiocaOFT10.address,
                    txData,
                    true,
                ),
            ).to.not.be.reverted;

            await expect(
                mtapiocaOFT10.unwrap(signer.address, dummyAmount),
            ).to.not.be.revertedWithCustomError(
                mtapiocaOFT10,
                'TOFT_NotAllowedChain',
            );
        });
        it('Should unwrap and give a 1:1 ratio amount of tokens', async () => {
            const {
                signer,
                mErc20Mock,
                mtapiocaOFT0,
                mintAndApprove,
                dummyAmount,
            } = await loadFixture(setupFixture);

            await mintAndApprove(mErc20Mock, mtapiocaOFT0, signer, dummyAmount);
            await mtapiocaOFT0.wrap(signer.address, dummyAmount);

            const balTOFTSignerBefore = await mtapiocaOFT0.balanceOf(
                signer.address,
            );
            const balERC20SignerBefore = await mErc20Mock.balanceOf(
                signer.address,
            );
            const balERC20ContractBefore = await mErc20Mock.balanceOf(
                mtapiocaOFT0.address,
            );

            await expect(mtapiocaOFT0.unwrap(signer.address, dummyAmount)).to
                .not.be.reverted;

            const balTOFTSignerAfter = await mtapiocaOFT0.balanceOf(
                signer.address,
            );
            const balERC20SignerAfter = await mErc20Mock.balanceOf(
                signer.address,
            );
            const balERC20ContractAfter = await mErc20Mock.balanceOf(
                mtapiocaOFT0.address,
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
});
