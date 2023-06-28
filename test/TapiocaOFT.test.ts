import { loadFixture } from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import hre, { ethers } from 'hardhat';
import {
    ERC20Mock__factory,
    LZEndpointMock__factory,
    YieldBoxMock__factory,
    TOFTStrategyMock__factory,
} from '../gitsub_tapioca-sdk/src/typechain/tapioca-mocks';

import {
    YieldBox__factory,
    YieldBoxURIBuilder__factory,
    YieldBox,
} from '../gitsub_tapioca-sdk/src/typechain/YieldBox';
import { BN, getERC20PermitSignature } from '../scripts/utils';
import { setupFixture } from './fixtures';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { TapiocaOFT } from '../typechain';

describe('TapiocaOFT', () => {
    it('simulate deploy', async () => {
        const deployer = (await ethers.getSigners())[0];
        const ERC20Mock = new ERC20Mock__factory(deployer);
        const erc20Mock = await ERC20Mock.deploy(
            'erc20Mock',
            'MOCK',
            0,
            18,
            deployer.address,
        );
        await erc20Mock.updateMintLimit(ethers.constants.MaxUint256);

        const LZEndpointMock = new LZEndpointMock__factory(deployer);
        const lzEndpoint = await LZEndpointMock.deploy(1);

        const YieldBoxMock = new YieldBoxMock__factory(deployer);
        const yieldBox = await YieldBoxMock.deploy();

        await (
            await hre.ethers.getContractFactory('TapiocaOFT')
        ).deploy(
            lzEndpoint.address,
            erc20Mock.address,
            yieldBox.address,
            'test',
            'tt',
            18,
            1,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
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
            ).to.be.reverted;
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

            await expect(tapiocaOFT10.unwrap(signer.address, dummyAmount)).to.be
                .reverted;
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
                    {
                        gasLimit: 2_000_000,
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
                        gasLimit: 2_000_000,
                    },
                ),
            ).to.not.be.reverted;
        });
    });

    describe('sendOrRetrieveStrategy', () => {
        const deployYieldBox = async (signer: SignerWithAddress) => {
            const YieldBoxURIBuilder = new YieldBoxURIBuilder__factory(signer);
            const YieldBox = new YieldBox__factory(signer);

            const uriBuilder = await YieldBoxURIBuilder.deploy();
            const yieldBox = await YieldBox.deploy(
                ethers.constants.AddressZero,
                uriBuilder.address,
            );
            return { uriBuilder, yieldBox };
        };

        const deployToftMockStrategy = async (
            signer: SignerWithAddress,
            yieldBoxAddress: string,
            toftAddress: string,
        ) => {
            const TOFTStrategyMock = new TOFTStrategyMock__factory(signer);

            const ERC20Mock = new ERC20Mock__factory(signer);
            const rewardToken = await ERC20Mock.deploy(
                'RewardMock',
                'RWRDM',
                0,
                18,
                signer.address,
            );
            await rewardToken.toggleRestrictions();

            const tOFTStrategyMock = await TOFTStrategyMock.deploy(
                yieldBoxAddress,
                toftAddress,
                rewardToken.address,
            );
            return { rewardToken, tOFTStrategyMock };
        };

        it('should be able to deposit & withdraw from a strategy available on another layer', async () => {
            const { signer, erc20Mock, mintAndApprove, bigDummyAmount, utils } =
                await loadFixture(setupFixture);

            const LZEndpointMock_chainID_0 = await utils.deployLZEndpointMock(
                31337,
            );
            const LZEndpointMock_chainID_10 = await utils.deployLZEndpointMock(
                10,
            );

            const tapiocaWrapper_0 = await utils.deployTapiocaWrapper();
            const tapiocaWrapper_10 = await utils.deployTapiocaWrapper();

            //Deploy YB and Strategies
            const yieldBox0Data = await deployYieldBox(signer);
            const yieldBox10Data = await deployYieldBox(signer);

            const YieldBox_0 = yieldBox0Data.yieldBox;
            const YieldBox_10 = yieldBox10Data.yieldBox;

            {
                const txData =
                    await tapiocaWrapper_0.populateTransaction.createTOFT(
                        erc20Mock.address,
                        (
                            await utils.Tx_deployTapiocaOFT(
                                LZEndpointMock_chainID_0.address,
                                erc20Mock.address,
                                YieldBox_0.address,
                                31337,
                                signer,
                            )
                        ).txData,
                        ethers.utils.randomBytes(32),
                        false,
                    );
                txData.gasLimit = await hre.ethers.provider.estimateGas(txData);
                await signer.sendTransaction(txData);
            }

            const tapiocaOFT0 = (await utils.attachTapiocaOFT(
                await tapiocaWrapper_0.tapiocaOFTs(
                    (await tapiocaWrapper_0.tapiocaOFTLength()).sub(1),
                ),
            )) as TapiocaOFT;

            // Deploy TapiocaOFT10
            {
                const txData =
                    await tapiocaWrapper_10.populateTransaction.createTOFT(
                        erc20Mock.address,
                        (
                            await utils.Tx_deployTapiocaOFT(
                                LZEndpointMock_chainID_10.address,
                                erc20Mock.address,
                                YieldBox_10.address,
                                10,
                                signer,
                            )
                        ).txData,
                        ethers.utils.randomBytes(32),
                        false,
                    );
                txData.gasLimit = await hre.ethers.provider.estimateGas(txData);
                await signer.sendTransaction(txData);
            }

            const tapiocaOFT10 = (await utils.attachTapiocaOFT(
                await tapiocaWrapper_10.tapiocaOFTs(
                    (await tapiocaWrapper_10.tapiocaOFTLength()).sub(1),
                ),
            )) as TapiocaOFT;

            const strategy0Data = await deployToftMockStrategy(
                signer,
                YieldBox_0.address,
                tapiocaOFT0.address,
            );
            const strategy10Data = await deployToftMockStrategy(
                signer,
                YieldBox_10.address,
                tapiocaOFT10.address,
            );

            const Strategy_0 = strategy0Data.tOFTStrategyMock;
            const Strategy_10 = strategy10Data.tOFTStrategyMock;

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
            const dstChainId0 = 31337;
            const dstChainId10 = 10;

            await tapiocaWrapper_0.executeTOFT(
                tapiocaOFT0.address,
                tapiocaOFT0.interface.encodeFunctionData('setTrustedRemote', [
                    dstChainId10,
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
                    dstChainId0,
                    ethers.utils.solidityPack(
                        ['address', 'address'],
                        [tapiocaOFT0.address, tapiocaOFT10.address],
                    ),
                ]),
                true,
            );
            // Link endpoints with addresses
            await LZEndpointMock_chainID_0.setDestLzEndpoint(
                tapiocaOFT10.address,
                LZEndpointMock_chainID_10.address,
            );
            await LZEndpointMock_chainID_10.setDestLzEndpoint(
                tapiocaOFT0.address,
                LZEndpointMock_chainID_0.address,
            );

            //Register tokens on YB
            await YieldBox_0.registerAsset(
                1,
                tapiocaOFT0.address,
                Strategy_0.address,
                0,
            );
            await YieldBox_10.registerAsset(
                1,
                tapiocaOFT10.address,
                Strategy_10.address,
                0,
            );

            const tapiocaOFT0Id = await YieldBox_0.ids(
                1,
                tapiocaOFT0.address,
                Strategy_0.address,
                0,
            );
            const tapiocaOFT10Id = await YieldBox_10.ids(
                1,
                tapiocaOFT10.address,
                Strategy_10.address,
                0,
            );

            expect(tapiocaOFT0Id.eq(1)).to.be.true;
            expect(tapiocaOFT10Id.eq(1)).to.be.true;

            //Test deposits on same chain
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

            await tapiocaOFT0.approve(
                YieldBox_0.address,
                ethers.constants.MaxUint256,
            );
            let toDepositShare = await YieldBox_0.toShare(
                tapiocaOFT0Id,
                bigDummyAmount,
                false,
            );
            await YieldBox_0.depositAsset(
                tapiocaOFT0Id,
                signer.address,
                signer.address,
                0,
                toDepositShare,
            );

            let yb0Balance = await YieldBox_0.amountOf(
                signer.address,
                tapiocaOFT0Id,
            );
            let vaultAmount = await Strategy_0.vaultAmount();
            expect(yb0Balance.gt(bigDummyAmount)).to.be.true; //bc of the yield
            expect(vaultAmount.eq(bigDummyAmount)).to.be.true;

            //Test withdraw on same chain
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
            await tapiocaOFT0.transfer(
                Strategy_0.address,
                yb0Balance.sub(bigDummyAmount),
            ); //assures the strategy has enough tokens to withdraw
            const signerBalanceBeforeWithdraw = await tapiocaOFT0.balanceOf(
                signer.address,
            );

            const toWithdrawShare = await YieldBox_0.balanceOf(
                signer.address,
                tapiocaOFT0Id,
            );
            await YieldBox_0.withdraw(
                tapiocaOFT0Id,
                signer.address,
                signer.address,
                0,
                toWithdrawShare,
            );
            const signerBalanceAfterWithdraw = await tapiocaOFT0.balanceOf(
                signer.address,
            );

            expect(
                signerBalanceAfterWithdraw
                    .sub(signerBalanceBeforeWithdraw)
                    .gt(bigDummyAmount),
            ).to.be.true;

            vaultAmount = await Strategy_0.vaultAmount();
            expect(vaultAmount.eq(0)).to.be.true;

            yb0Balance = await YieldBox_0.amountOf(
                signer.address,
                tapiocaOFT0Id,
            );
            expect(vaultAmount.eq(0)).to.be.true;

            const latestBalance = await Strategy_0.currentBalance();
            expect(latestBalance.eq(0)).to.be.true;

            toDepositShare = await YieldBox_0.toShare(
                tapiocaOFT0Id,
                bigDummyAmount,
                false,
            );

            const totals = await YieldBox_0.assetTotals(tapiocaOFT0Id);
            expect(totals[0].eq(0)).to.be.true;
            expect(totals[1].eq(0)).to.be.true;

            //Cross chain deposit from TapiocaOFT_10 to Strategy_0
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
                        value: ethers.utils.parseEther('0.02'),
                        gasLimit: 2_000_000,
                    },
                ),
            ).to.not.be.reverted;
            const signerBalanceForTOFT10 = await tapiocaOFT10.balanceOf(
                signer.address,
            );
            expect(signerBalanceForTOFT10.eq(bigDummyAmount)).to.be.true;

            const asset = await YieldBox_0.assets(tapiocaOFT0Id);
            expect(asset[2]).to.eq(Strategy_0.address);

            await tapiocaOFT10.sendToStrategy(
                signer.address,
                signer.address,
                bigDummyAmount,
                toDepositShare,
                1, //asset id
                dstChainId0,
                {
                    extraGasLimit: '2500000',
                    zroPaymentAddress: ethers.constants.AddressZero,
                },
                {
                    value: ethers.utils.parseEther('15'),
                },
            );

            let strategy0Amount = await Strategy_0.vaultAmount();
            expect(strategy0Amount.gt(0)).to.be.true;

            const yb0BalanceAfterCrossChainDeposit = await YieldBox_0.amountOf(
                signer.address,
                tapiocaOFT0Id,
            );
            expect(yb0BalanceAfterCrossChainDeposit.gt(bigDummyAmount));

            const airdropAdapterParams = ethers.utils.solidityPack(
                ['uint16', 'uint', 'uint', 'address'],
                [2, 800000, ethers.utils.parseEther('2'), tapiocaOFT0.address],
            );

            await YieldBox_0.setApprovalForAsset(
                tapiocaOFT0.address,
                tapiocaOFT0Id,
                true,
            ); //this should be done through Magnetar in the same tx, to avoid frontrunning

            yb0Balance = await YieldBox_0.amountOf(
                signer.address,
                tapiocaOFT0Id,
            );

            await tapiocaOFT0.transfer(
                Strategy_0.address,
                yb0Balance.sub(bigDummyAmount),
            ); //assures the strategy has enough tokens to withdraw
            await tapiocaOFT10.retrieveFromStrategy(
                signer.address,
                yb0BalanceAfterCrossChainDeposit,
                toWithdrawShare,
                1,
                dstChainId0,
                ethers.constants.AddressZero,
                airdropAdapterParams,
                {
                    value: ethers.utils.parseEther('10'),
                },
            );
            strategy0Amount = await Strategy_0.vaultAmount();
            expect(strategy0Amount.eq(0)).to.be.true;

            const signerBalanceAfterCrossChainWithdrawal =
                await tapiocaOFT10.balanceOf(signer.address);
            expect(signerBalanceAfterCrossChainWithdrawal.gt(bigDummyAmount)).to
                .be.true;
        });
    });
});
