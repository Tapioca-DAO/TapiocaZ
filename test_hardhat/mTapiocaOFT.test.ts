import {
    loadFixture,
    takeSnapshot,
    time,
} from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { ethers } from 'hardhat';
import { BN, getERC20PermitSignature } from '../scripts/utils';
import { setupFixture } from './fixtures';
import {
    LZEndpointMock__factory,
    YieldBoxMock__factory,
} from '@tapioca-sdk/typechain/tapioca-mocks';
import { Cluster__factory } from '@tapioca-sdk/typechain/tapioca-periphery';
import { TOFTVault__factory } from '@typechain/index';

describe('mTapiocaOFT', () => {
    describe('extractFees()', () => {
        it('should extract fees', async () => {
            const { signer, mErc20Mock, mintAndApprove, dummyAmount } =
                await loadFixture(setupFixture);

            const mToftFactory = await ethers.getContractFactory('mTOFT');

            const Cluster = new Cluster__factory(signer);
            const Cluster_0 = await Cluster.deploy(31337, signer.address);

            const YieldBoxMock = new YieldBoxMock__factory(signer);
            const YieldBox_0 = await YieldBoxMock.deploy();

            const LZEndpointMock = new LZEndpointMock__factory(signer);
            const lzEndpoint0 = await LZEndpointMock.deploy(31337);

            const vaultFactory = new TOFTVault__factory(signer);
            const deployedVault = await vaultFactory.deploy(mErc20Mock.address);

            const initStruct = {
                name: 'mtapiocaOFT',
                symbol: 'mt',
                endpoint: lzEndpoint0.address,
                delegate: signer.address,
                yieldBox: YieldBox_0.address,
                cluster: Cluster_0.address,
                erc20: mErc20Mock.address,
                hostEid: 10,
                extExec: ethers.constants.AddressZero,
                vault: deployedVault.address
            };
            const mtoftSender = await (
                await ethers.getContractFactory('TOFTSender')
            ).deploy(initStruct);
            const mtoftReceiver = await (
                await ethers.getContractFactory('TOFTReceiver')
            ).deploy(initStruct);
            const mtoftGenericReceiver = await (
                await ethers.getContractFactory('TOFTGenericReceiverModule')
            ).deploy(initStruct);
            const mtoftMarketReceiver = await (
                await ethers.getContractFactory('TOFTMarketReceiverModule')
            ).deploy(initStruct);
            const mtoftOptionsReceiver = await (
                await ethers.getContractFactory('TOFTOptionsReceiverModule')
            ).deploy(initStruct);
            const mtapiocaOFT = await mToftFactory.deploy(
                initStruct,
                {
                    tOFTSenderModule: mtoftSender.address,
                    tOFTReceiverModule: mtoftReceiver.address,
                    marketReceiverModule: mtoftMarketReceiver.address,
                    optionsReceiverModule: mtoftOptionsReceiver.address,
                    genericReceiverModule: mtoftGenericReceiver.address,
                },
                ethers.constants.AddressZero,
            );
            await mtapiocaOFT.deployed();
            const fee = 1e4;
            let ownerStateData = {
                stargateRouter: ethers.constants.AddressZero,
                mintFee: fee,
                mintCap: 0,
                connectedChain: 31337,
                connectedChainState: true,
                balancerStateAddress: ethers.constants.AddressZero,
                balancerState: false,
            };
            await mtapiocaOFT.setOwnerState(ownerStateData);

            await mintAndApprove(mErc20Mock, mtapiocaOFT, signer, dummyAmount);

            const balTOFTSignerBefore = await mtapiocaOFT.balanceOf(
                signer.address,
            );
            const vault = await ethers.getContractAt(
                'TOFTVault',
                await mtapiocaOFT.vault(),
            );
            const balERC20ContractBefore = await mErc20Mock.balanceOf(
                vault.address,
            );

            await mtapiocaOFT.wrap(signer.address, signer.address, dummyAmount);

            const balTOFTSignerAfter = await mtapiocaOFT.balanceOf(
                signer.address,
            );
            const balERC20ContractAfter = await mErc20Mock.balanceOf(
                vault.address,
            );
            const dummyAmountMinusFee = dummyAmount.sub(
                dummyAmount.mul(fee).div(1e5),
            );
            expect(balTOFTSignerAfter).eq(
                balTOFTSignerBefore.add(dummyAmountMinusFee),
            );
            expect(balERC20ContractAfter).eq(
                balERC20ContractBefore.add(dummyAmount),
            );

            const vaultActiveSupply = await vault.viewSupply();
            const vaultFeeSupply = await vault.viewFees();
            const vaultTotalSupply = await vault.viewTotalSupply();
            const toftTotalSupply = await mtapiocaOFT.totalSupply();
            expect(vaultActiveSupply.eq(dummyAmountMinusFee)).to.be.true;
            expect(vaultFeeSupply.eq(dummyAmount.mul(fee).div(1e5))).to.be.true;
            expect(vaultTotalSupply.eq(dummyAmount)).to.be.true;
            expect(toftTotalSupply.eq(dummyAmountMinusFee)).to.be.true;

            ownerStateData = {
                stargateRouter: ethers.constants.AddressZero,
                mintFee: 1e4,
                mintCap: dummyAmount.div(2),
                connectedChain: 0,
                connectedChainState: false,
                balancerStateAddress: ethers.constants.AddressZero,
                balancerState: false,
            };
            await expect(mtapiocaOFT.setOwnerState(ownerStateData)).to.be
                .reverted;

            ownerStateData = {
                stargateRouter: ethers.constants.AddressZero,
                mintFee: 1e4,
                mintCap: dummyAmount.add(1),
                connectedChain: 0,
                connectedChainState: false,
                balancerStateAddress: ethers.constants.AddressZero,
                balancerState: false,
            };
            await expect(mtapiocaOFT.setOwnerState(ownerStateData)).to.not.be
                .reverted;

            await mintAndApprove(mErc20Mock, mtapiocaOFT, signer, dummyAmount);
            await expect(
                mtapiocaOFT.wrap(signer.address, signer.address, dummyAmount),
            ).to.be.revertedWithCustomError(mtapiocaOFT, 'mTOFT_CapNotValid');

            await mtapiocaOFT.withdrawFees(
                signer.address,
                await vault.viewFees(),
            );

            const viewFees = await vault.viewFees();
            expect(viewFees.eq(0)).to.be.true;
        });
    });
    describe('extractUnderlying()', () => {
        it('should fail for unknown balance', async () => {
            const { signer, mtapiocaOFT0, mErc20Mock } = await loadFixture(
                setupFixture,
            );

            let balancerStatus = await mtapiocaOFT0.balancers(signer.address);
            expect(balancerStatus).to.be.false;

            await expect(mtapiocaOFT0.extractUnderlying(1)).to.be.reverted;

            const ownerStateData = {
                stargateRouter: ethers.constants.AddressZero,
                mintFee: 0,
                mintCap: 0,
                connectedChain: 0,
                connectedChainState: false,
                balancerStateAddress: signer.address,
                balancerState: true,
            };
            await mtapiocaOFT0.setOwnerState(ownerStateData);

            balancerStatus = await mtapiocaOFT0.balancers(signer.address);
            expect(balancerStatus).to.be.true;

            const vault = await mtapiocaOFT0.vault();
            await mErc20Mock.freeMint(1);
            await mErc20Mock.transfer(vault, 1);

            await expect(mtapiocaOFT0.extractUnderlying(1)).to.not.be.reverted;
        });
    });

    describe('wrap()', () => {
        it('Should fail if not approved', async () => {
            const {
                signer,
                randomUser,
                mtapiocaOFT0,
                dummyAmount,
                mErc20Mock,
                mintAndApprove,
            } = await loadFixture(setupFixture);
            await mintAndApprove(
                mErc20Mock,
                mtapiocaOFT0,
                signer,
                BN(dummyAmount),
            );

            // Check failure with no allowance
            await expect(
                mtapiocaOFT0
                    .connect(randomUser)
                    .wrap(signer.address, randomUser.address, dummyAmount),
            ).to.be.reverted;

            // Approve and check allowance
            await mtapiocaOFT0.approve(randomUser.address, dummyAmount);
            expect(
                await mtapiocaOFT0.allowance(
                    signer.address,
                    randomUser.address,
                ),
            ).to.be.equal(dummyAmount);

            // Check success after allowance
            await expect(
                mtapiocaOFT0
                    .connect(randomUser)
                    .wrap(signer.address, signer.address, dummyAmount),
            ).to.not.be.reverted;
        });
        it('Should fail if not on the same chain', async () => {
            const {
                signer,
                mtapiocaOFT0,
                mtapiocaOFT10,
                dummyAmount,
                mErc20Mock,
                mintAndApprove,
            } = await loadFixture(setupFixture);

            await mintAndApprove(
                mErc20Mock,
                mtapiocaOFT0,
                signer,
                BN(dummyAmount),
            );
            await expect(
                mtapiocaOFT10.wrap(signer.address, signer.address, dummyAmount),
            ).to.be.reverted;
        });

        it('Should wrap and give a 1:1 ratio amount of tokens', async () => {
            const {
                signer,
                mErc20Mock,
                mtapiocaOFT0,
                mintAndApprove,
                dummyAmount,
            } = await loadFixture(setupFixture);

            await mintAndApprove(mErc20Mock, mtapiocaOFT0, signer, dummyAmount);

            const balTOFTSignerBefore = await mtapiocaOFT0.balanceOf(
                signer.address,
            );
            const vault = await mtapiocaOFT0.vault();
            const balERC20ContractBefore = await mErc20Mock.balanceOf(vault);

            await mtapiocaOFT0.wrap(
                signer.address,
                signer.address,
                dummyAmount,
            );

            const balTOFTSignerAfter = await mtapiocaOFT0.balanceOf(
                signer.address,
            );
            const balERC20ContractAfter = await mErc20Mock.balanceOf(vault);
            expect(balTOFTSignerAfter).eq(balTOFTSignerBefore.add(dummyAmount));
            expect(balERC20ContractAfter).eq(
                balERC20ContractBefore.add(dummyAmount),
            );
        });

        it('Should be able to extract tokens', async () => {
            const {
                signer,
                mErc20Mock,
                mtapiocaOFT0,
                mintAndApprove,
                dummyAmount,
            } = await loadFixture(setupFixture);

            await mintAndApprove(mErc20Mock, mtapiocaOFT0, signer, dummyAmount);

            await mtapiocaOFT0.wrap(
                signer.address,
                signer.address,
                dummyAmount,
            );

            const signerBalanceBefore = await mErc20Mock.balanceOf(
                signer.address,
            );
            expect(signerBalanceBefore.eq(0)).to.be.true;

            await expect(mtapiocaOFT0.extractUnderlying(dummyAmount)).to.be
                .reverted;

            const ownerStateData = {
                stargateRouter: ethers.constants.AddressZero,
                mintFee: 0,
                mintCap: 0,
                connectedChain: 0,
                connectedChainState: false,
                balancerStateAddress: signer.address,
                balancerState: true,
            };
            await mtapiocaOFT0.setOwnerState(ownerStateData);

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
            const { signer, mtapiocaOFT0, mtapiocaOFT10, dummyAmount } =
                await loadFixture(setupFixture);

            await expect(mtapiocaOFT10.unwrap(signer.address, dummyAmount)).to
                .be.reverted;
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
            await mtapiocaOFT0.wrap(
                signer.address,
                signer.address,
                dummyAmount,
            );

            const balTOFTSignerBefore = await mtapiocaOFT0.balanceOf(
                signer.address,
            );
            const balERC20SignerBefore = await mErc20Mock.balanceOf(
                signer.address,
            );

            const vault = await mtapiocaOFT0.vault();
            const balERC20ContractBefore = await mErc20Mock.balanceOf(vault);

            await expect(mtapiocaOFT0.unwrap(signer.address, dummyAmount)).to
                .not.be.reverted;

            const balTOFTSignerAfter = await mtapiocaOFT0.balanceOf(
                signer.address,
            );
            const balERC20SignerAfter = await mErc20Mock.balanceOf(
                signer.address,
            );
            const balERC20ContractAfter = await mErc20Mock.balanceOf(vault);

            expect(balTOFTSignerAfter).eq(balTOFTSignerBefore.sub(dummyAmount));
            expect(balERC20SignerAfter).eq(
                balERC20SignerBefore.add(dummyAmount),
            );
            expect(balERC20ContractAfter).eq(
                balERC20ContractBefore.sub(dummyAmount),
            );
        });
    });

    it('Should be able to use permit', async () => {
        const { signer, randomUser, mtapiocaOFT0, mintAndApprove, mErc20Mock } =
            await loadFixture(setupFixture);

        await mintAndApprove(
            mErc20Mock,
            mtapiocaOFT0,
            signer,
            (1e18).toString(),
        );

        await mtapiocaOFT0.wrap(
            signer.address,
            signer.address,
            (1e18).toString(),
        );

        const deadline =
            (await ethers.provider.getBlock('latest')).timestamp + 10_000;

        const { v, r, s } = await getERC20PermitSignature(
            signer,
            mtapiocaOFT0,
            randomUser.address,
            (1e18).toString(),
            BN(deadline),
        );

        // Check if it works
        const snapshot = await takeSnapshot();
        await expect(
            mtapiocaOFT0.permit(
                signer.address,
                randomUser.address,
                (1e18).toString(),
                deadline,
                v,
                r,
                s,
            ),
        )
            .to.emit(mtapiocaOFT0, 'Approval')
            .withArgs(signer.address, randomUser.address, (1e18).toString());

        // Check that it can't be used twice
        await expect(
            mtapiocaOFT0.permit(
                signer.address,
                randomUser.address,
                (1e18).toString(),
                deadline,
                v,
                r,
                s,
            ),
        ).to.be.reverted;
        await snapshot.restore();

        // Check that it can't be used after deadline
        await time.increase(10_001);
        await expect(
            mtapiocaOFT0.permit(
                signer.address,
                randomUser.address,
                (1e18).toString(),
                deadline,
                v,
                r,
                s,
            ),
        ).to.be.reverted;
        await snapshot.restore();

        // Check that it can't be used with wrong signature
        const {
            v: v2,
            r: r2,
            s: s2,
        } = await getERC20PermitSignature(
            signer,
            mtapiocaOFT0,
            randomUser.address,
            (1e18).toString(),
            BN(deadline),
        );
        await expect(
            mtapiocaOFT0.permit(
                signer.address,
                signer.address, // Wrong address
                (1e18).toString(),
                deadline,
                v2,
                r2,
                s2,
            ),
        ).to.be.reverted;
        await snapshot.restore();
    });
});
