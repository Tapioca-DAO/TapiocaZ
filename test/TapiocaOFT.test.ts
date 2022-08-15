import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber, BigNumberish, BytesLike } from 'ethers';
import hre, { ethers } from 'hardhat';
import { BN } from '../scripts/utils';
import {
    ERC20,
    ERC20Mock,
    LZEndpointMock,
    TapiocaOFTMock,
    TapiocaWrapper,
} from '../typechain';
import { register } from './test.utils';

describe('TapiocaOFT', () => {
    let signer: SignerWithAddress;

    let LZEndpointMock0: LZEndpointMock;
    let LZEndpointMock1: LZEndpointMock;
    let tapiocaWrapper: TapiocaWrapper;

    let erc20Mock0: ERC20Mock;
    let erc20Mock1: ERC20Mock;

    let tapiocaOFT0: TapiocaOFTMock;
    let tapiocaOFT1: TapiocaOFTMock;

    const amount = ethers.BigNumber.from(1e5);

    beforeEach(async () => {
        signer = (await ethers.getSigners())[0];

        const {
            LZEndpointMock0: _LZEndpointMock0,
            LZEndpointMock1: _LZEndpointMock1,
            tapiocaWrapper: _tapiocaWrapper,
            utils,
        } = await register(hre);
        LZEndpointMock0 = _LZEndpointMock0;
        LZEndpointMock1 = _LZEndpointMock1;

        tapiocaWrapper = _tapiocaWrapper;
        await tapiocaWrapper.setMngmtFee(25); // 0.25%

        erc20Mock0 = await (
            await hre.ethers.getContractFactory('ERC20Mock')
        ).deploy('erc20Mock0', 'MOCK0');

        erc20Mock1 = await (
            await hre.ethers.getContractFactory('ERC20Mock')
        ).deploy('erc20Mock1', 'MOCK1');

        // Deploy TapiocaOFT0
        await tapiocaWrapper.createTOFT(
            erc20Mock0.address,
            (
                await utils.Tx_deployTapiocaOFT(
                    LZEndpointMock0.address,
                    erc20Mock0.address,
                    0,
                    signer,
                )
            ).txData,
        );

        tapiocaOFT0 = (await utils.attachTapiocaOFT(
            await tapiocaWrapper.tapiocaOFTs(
                (await tapiocaWrapper.tapiocaOFTLength()).sub(1),
            ),
        )) as TapiocaOFTMock;
        tapiocaOFT0.setChainId(0);

        // Deploy TapiocaOFT1
        await tapiocaWrapper.createTOFT(
            erc20Mock1.address,
            (
                await utils.Tx_deployTapiocaOFT(
                    LZEndpointMock1.address,
                    erc20Mock1.address,
                    0,
                    signer,
                )
            ).txData,
        );

        tapiocaOFT1 = (await utils.attachTapiocaOFT(
            await tapiocaWrapper.tapiocaOFTs(
                (await tapiocaWrapper.tapiocaOFTLength()).sub(1),
            ),
        )) as TapiocaOFTMock;
        tapiocaOFT1.setChainId(1);

        // Link endpoints with addresses
        LZEndpointMock0.setDestLzEndpoint(
            tapiocaOFT1.address,
            LZEndpointMock1.address,
        );
        LZEndpointMock1.setDestLzEndpoint(
            tapiocaOFT0.address,
            LZEndpointMock0.address,
        );
    });

    const estimateFees = async (amount: BigNumberish) =>
        await tapiocaOFT0.estimateFees(
            await tapiocaWrapper.mngmtFee(),
            await tapiocaWrapper.mngmtFeeFraction(),
            amount,
        );

    const mintAndApprove = async (
        erc20Mock: ERC20Mock,
        toft: TapiocaOFTMock,
        signer: SignerWithAddress,
        amount: BigNumberish,
    ) => {
        const fees = await estimateFees(amount);
        const amountWithFees = BN(amount).add(fees);

        await erc20Mock.mint(signer.address, amountWithFees);
        await erc20Mock.approve(toft.address, amountWithFees);
    };

    it('decimals()', async () => {
        expect(await tapiocaOFT0.decimals()).eq(18);
        expect(await tapiocaOFT1.decimals()).eq(18);
    });

    describe('wrap()', () => {
        it('Should fail if not on the same chain', async () => {
            await mintAndApprove(erc20Mock1, tapiocaOFT1, signer, amount);
            await expect(
                tapiocaOFT1.wrap(signer.address, amount),
            ).to.be.revertedWith('NotMainChain');

            await mintAndApprove(erc20Mock0, tapiocaOFT0, signer, amount);
            await expect(tapiocaOFT0.wrap(signer.address, amount)).to.not.be
                .reverted;
        });

        it('Should fail if the fees are not paid', async () => {
            await mintAndApprove(
                erc20Mock0,
                tapiocaOFT0,
                signer,
                BN(amount).sub(await estimateFees(amount)),
            );
            await expect(
                tapiocaOFT0.wrap(signer.address, amount),
            ).to.be.revertedWith('ERC20: insufficient allowance');
        });

        it('Should wrap and give a 1:1 ratio amount of tokens', async () => {
            await mintAndApprove(erc20Mock0, tapiocaOFT0, signer, amount);
            await tapiocaOFT0.wrap(signer.address, amount);
            expect(await tapiocaOFT0.balanceOf(signer.address)).eq(amount);
            expect(await erc20Mock0.balanceOf(signer.address)).eq(0);
        });
    });

    describe('sendFrom()', () => {
        it('Should fail if untrusted remote', async () => {
            // Setup
            await mintAndApprove(erc20Mock0, tapiocaOFT0, signer, amount);
            await tapiocaOFT0.wrap(signer.address, amount);

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
                    tapiocaOFT1.address,
                ]),
            );
            await tapiocaWrapper.executeTOFT(
                tapiocaOFT1.address,
                tapiocaOFT1.interface.encodeFunctionData('setTrustedRemote', [
                    0,
                    tapiocaOFT0.address,
                ]),
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
            await mintAndApprove(erc20Mock0, tapiocaOFT0, signer, amount);
            await tapiocaOFT0.wrap(signer.address, amount);

            const fees = await estimateFees(amount);
            expect(fees.gt(0)).to.be.true;

            await expect(tapiocaOFT0.harvestFees()).to.emit(
                tapiocaOFT0,
                'Harvest',
            );

            await expect(tapiocaOFT1.harvestFees()).to.be.revertedWith(
                'NotMainChain',
            );
        });

        it('Should withdraw the fees and update the total fee balance', async () => {
            await mintAndApprove(erc20Mock0, tapiocaOFT0, signer, amount);
            await tapiocaOFT0.wrap(signer.address, amount);

            const feesBefore = await tapiocaOFT0.totalFees();

            await tapiocaOFT0.harvestFees();

            expect(await erc20Mock0.balanceOf(tapiocaWrapper.address)).eq(
                feesBefore,
            );

            const feesAfter = await tapiocaOFT0.totalFees();
            expect(feesAfter).eq(0);
        });
    });
});
