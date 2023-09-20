import {
    loadFixture,
    setBalance,
} from '@nomicfoundation/hardhat-network-helpers';
import { expect } from 'chai';
import { BytesLike } from 'ethers';
import hre, { ethers } from 'hardhat';
import { ERC20Mock__factory } from '../gitsub_tapioca-sdk/src/typechain/tapioca-mocks';
import { Cluster__factory } from '../gitsub_tapioca-sdk/src/typechain/tapioca-periphery';
import { generateSalt, useUtils } from '../scripts/utils';
import { TapiocaOFT__factory } from '../typechain';
import { setupFixture } from './fixtures';

describe('TapiocaWrapper', () => {
    describe('constructor()', () => {
        it('Should be owned by the deployer', async () => {
            const { signer, tapiocaWrapper_0 } = await loadFixture(
                setupFixture,
            );
            expect(await tapiocaWrapper_0.owner()).eq(signer.address);
        });
    });

    describe('createTOFT()', () => {
        it('Should be only owner', async () => {
            const {
                tapiocaWrapper_0,
                utils: { newEOA },
            } = await loadFixture(setupFixture);
            const eoa = newEOA();
            await setBalance(eoa.address, ethers.utils.parseEther('100000'));
            await expect(
                tapiocaWrapper_0
                    .connect(eoa)
                    .createTOFT(
                        eoa.address,
                        ethers.utils.randomBytes(32),
                        ethers.utils.randomBytes(32),
                        false,
                    ),
            ).to.be.revertedWith('Ownable: caller is not the owner');
        });

        it('Should fail if the ERC20 address is not the same as the registered TapiocaWrapper one', async () => {
            const { tapiocaWrapper_0, LZEndpointMock_chainID_0 } =
                await loadFixture(setupFixture);

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

            const Cluster = new Cluster__factory(deployer);
            const cluster = await Cluster.deploy(1);

            const args: Parameters<TapiocaOFT__factory['deploy']> = [
                LZEndpointMock_chainID_0.address,
                erc20Mock.address,
                ethers.constants.AddressZero,
                cluster.address,
                'erc20name',
                'erc20symbol',
                2,
                0,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero,
            ];
            const txData = (
                await ethers.getContractFactory('TapiocaOFT')
            ).getDeployTransaction(...args).data as BytesLike;

            await expect(
                tapiocaWrapper_0.createTOFT(
                    ethers.Wallet.createRandom().address,
                    txData,
                    generateSalt(),
                    false,
                ),
            ).to.be.revertedWithCustomError(
                tapiocaWrapper_0,
                'TapiocaWrapper__FailedDeploy',
            );
        });

        it('Should create an OFT, add it to `tapiocaOFTs`, `harvestableTapiocaOFTs` array and `tapiocaOFTsByErc20` map', async () => {
            const { tapiocaWrapper_0, LZEndpointMock_chainID_0 } =
                await loadFixture(setupFixture);

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
            const erc20Name = 'erc20name';

            const Cluster = new Cluster__factory(deployer);
            const cluster = await Cluster.deploy(1);

            const args: Parameters<TapiocaOFT__factory['deploy']> = [
                LZEndpointMock_chainID_0.address,
                erc20Mock.address,
                ethers.constants.AddressZero,
                cluster.address,
                erc20Name,
                'erc20symbol',
                2,
                0,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero,
            ];
            // Prepare the transaction data and call create
            const txData = (
                await ethers.getContractFactory('TapiocaOFT')
            ).getDeployTransaction(...args).data as BytesLike;

            const salt = generateSalt();
            await expect(
                await tapiocaWrapper_0.createTOFT(
                    erc20Mock.address,
                    txData,
                    salt,
                    false,
                ),
            ).to.not.be.reverted;

            // Check state variables correctness
            const tapiocaOFTArrayValue = await tapiocaWrapper_0.tapiocaOFTs(
                (await tapiocaWrapper_0.tapiocaOFTLength()).sub(1),
            );
            const tapiocaOFTMapValue =
                await tapiocaWrapper_0.tapiocaOFTsByErc20(erc20Mock.address);
            expect(tapiocaOFTArrayValue).to.not.equal(
                erc20Mock.address,
                'tapiocaOFTs array should not be empty',
            );
            expect(tapiocaOFTMapValue).to.not.equal(
                erc20Mock.address,
                'tapiocaOFTsByErc20 map should contains the new OFT address',
            );
            expect(tapiocaOFTArrayValue).to.eq(
                tapiocaOFTMapValue,
                'Map and array values should be equal',
            );

            // Check the OFT state variables correctness
            const tapiocaOFT = await ethers.getContractAt(
                'TapiocaOFT',
                tapiocaOFTArrayValue,
            );

            expect(await tapiocaOFT.name()).to.eq(`TapiocaOFT-${erc20Name}`);
        });

        it('Should create an mOFT, add it to `tapiocaOFTs`, `harvestableTapiocaOFTs` array and `tapiocaOFTsByErc20` map', async () => {
            const { tapiocaWrapper_0, LZEndpointMock_chainID_0 } =
                await loadFixture(setupFixture);

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
            const erc20Name = 'erc20name';

            const Cluster = new Cluster__factory(deployer);
            const cluster = await Cluster.deploy(1);

            const args: Parameters<TapiocaOFT__factory['deploy']> = [
                LZEndpointMock_chainID_0.address,
                erc20Mock.address,
                ethers.constants.AddressZero,
                cluster.address,
                erc20Name,
                'erc20symbol',
                2,
                0,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero,
            ];
            // Prepare the transaction data and call create
            const txData = (
                await ethers.getContractFactory('mTapiocaOFT')
            ).getDeployTransaction(...args).data as BytesLike;

            const salt = generateSalt();
            await expect(
                await tapiocaWrapper_0.createTOFT(
                    erc20Mock.address,
                    txData,
                    salt,
                    true,
                ),
            ).to.not.be.reverted;

            // Check state variables correctness
            const tapiocaOFTArrayValue = await tapiocaWrapper_0.tapiocaOFTs(
                (await tapiocaWrapper_0.tapiocaOFTLength()).sub(1),
            );
            const tapiocaOFTMapValue =
                await tapiocaWrapper_0.tapiocaOFTsByErc20(erc20Mock.address);
            expect(tapiocaOFTArrayValue).to.not.equal(
                erc20Mock.address,
                'tapiocaOFTs array should not be empty',
            );
            expect(tapiocaOFTMapValue).to.not.equal(
                erc20Mock.address,
                'tapiocaOFTsByErc20 map should contains the new OFT address',
            );
            expect(tapiocaOFTArrayValue).to.eq(
                tapiocaOFTMapValue,
                'Map and array values should be equal',
            );

            // Check the OFT state variables correctness
            const tapiocaOFT = await ethers.getContractAt(
                'mTapiocaOFT',
                tapiocaOFTArrayValue,
            );

            expect(await tapiocaOFT.name()).to.eq(`TapiocaOFT-${erc20Name}`);
        });

        it('Should create both an OFT and a mOFT, add it to `tapiocaOFTs`, `harvestableTapiocaOFTs` array and `tapiocaOFTsByErc20` map', async () => {
            const { tapiocaWrapper_0, LZEndpointMock_chainID_0 } =
                await loadFixture(setupFixture);

            const deployer = (await ethers.getSigners())[0];
            const ERC20Mock = new ERC20Mock__factory(deployer);
            let erc20Mock = await ERC20Mock.deploy(
                'erc20Mock',
                'MOCK',
                0,
                18,
                deployer.address,
            );
            await erc20Mock.updateMintLimit(ethers.constants.MaxUint256);
            let erc20Name = 'erc20name';

            const Cluster = new Cluster__factory(deployer);
            const cluster = await Cluster.deploy(1);

            const args: Parameters<TapiocaOFT__factory['deploy']> = [
                LZEndpointMock_chainID_0.address,
                erc20Mock.address,
                ethers.constants.AddressZero,
                cluster.address,
                erc20Name,
                'erc20symbol',
                2,
                0,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero,
            ];
            // Prepare the transaction data and call create
            const txData = (
                await ethers.getContractFactory('TapiocaOFT')
            ).getDeployTransaction(...args).data as BytesLike;

            await expect(
                tapiocaWrapper_0.createTOFT(
                    erc20Mock.address,
                    txData,
                    generateSalt(),
                    false,
                ),
            ).to.not.be.reverted;

            let mtxData = (
                await ethers.getContractFactory('mTapiocaOFT')
            ).getDeployTransaction(...args).data as BytesLike;

            await expect(
                tapiocaWrapper_0.createTOFT(
                    erc20Mock.address,
                    mtxData,
                    generateSalt(),
                    true,
                ),
            ).to.be.reverted;

            erc20Mock = await ERC20Mock.deploy(
                'erc20Mock',
                'MOCK',
                0,
                18,
                deployer.address,
            );
            await erc20Mock.updateMintLimit(ethers.constants.MaxUint256);
            erc20Name = 'erc20name2';

            const mArgs: Parameters<TapiocaOFT__factory['deploy']> = [
                LZEndpointMock_chainID_0.address,
                erc20Mock.address,
                ethers.constants.AddressZero,
                cluster.address,
                erc20Name,
                'erc20symbol2',
                2,
                0,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero,
                ethers.constants.AddressZero,
            ];
            mtxData = (
                await ethers.getContractFactory('mTapiocaOFT')
            ).getDeployTransaction(...mArgs).data as BytesLike;

            await expect(
                tapiocaWrapper_0.createTOFT(
                    erc20Mock.address,
                    mtxData,
                    generateSalt(),
                    true,
                ),
            ).to.not.be.reverted;
        });
    });

    describe('tapiocaOFTLength()', () => {
        it('Should return the length of the `tapiocaOFTs` array', async () => {
            const { signer, erc20Mock, LZEndpointMock_chainID_0 } =
                await loadFixture(setupFixture);
            const { Tx_deployTapiocaOFT, deployTapiocaWrapper } = useUtils(
                hre,
                signer,
            );

            const tapiocaWrapper = await deployTapiocaWrapper();

            expect(await tapiocaWrapper.tapiocaOFTLength()).to.eq(0);
            const Cluster = new Cluster__factory(signer);
            const cluster = await Cluster.deploy(1);

            const { txData: bytecode } = await Tx_deployTapiocaOFT(
                LZEndpointMock_chainID_0.address,
                erc20Mock.address,
                ethers.constants.AddressZero,
                cluster.address,
                0,
                signer,
            );
            await tapiocaWrapper.createTOFT(
                erc20Mock.address,
                bytecode,
                generateSalt(),
                false,
            );
            expect(await tapiocaWrapper.tapiocaOFTLength()).to.eq(1);
        });
    });

    describe('harvestableTapiocaOFTsLength()', () => {
        it('Should return the correct length of the `harvestableTapiocaOFTs` array', async () => {
            const {
                signer,
                erc20Mock,
                erc20Mock1,
                LZEndpointMock_chainID_0,
                LZEndpointMock_chainID_10,
            } = await loadFixture(setupFixture);
            const { Tx_deployTapiocaOFT, deployTapiocaWrapper } = useUtils(
                hre,
                signer,
            );

            const tapiocaWrapper = await deployTapiocaWrapper();

            expect(await tapiocaWrapper.harvestableTapiocaOFTsLength()).to.eq(
                0,
            );

            const Cluster = new Cluster__factory(signer);
            const cluster = await Cluster.deploy(1);

            // First TOFT on chain 0, should be added to the harvestable array
            const { txData: bytecode } = await Tx_deployTapiocaOFT(
                LZEndpointMock_chainID_0.address,
                erc20Mock.address,
                ethers.constants.AddressZero,
                cluster.address,
                31337,
                signer,
            );
            await tapiocaWrapper.createTOFT(
                erc20Mock.address,
                bytecode,
                generateSalt(),
                false,
            );
            expect(await tapiocaWrapper.harvestableTapiocaOFTsLength()).to.eq(
                1,
            );

            // Second TOFT on chain 10, should not be added to the harvestable array
            const { txData: bytecode10 } = await Tx_deployTapiocaOFT(
                LZEndpointMock_chainID_10.address,
                erc20Mock1.address,
                ethers.constants.AddressZero,
                cluster.address,
                10,
                signer,
            );
            await tapiocaWrapper.createTOFT(
                erc20Mock1.address,
                bytecode10,
                generateSalt(),
                false,
            );
            expect(await tapiocaWrapper.harvestableTapiocaOFTsLength()).to.eq(
                1,
            );
        });
    });

    describe('lastTOFT()', () => {
        it('Should fail if no TOFT has been created yet', async () => {
            const { signer } = await loadFixture(setupFixture);
            const tapiocaWrapper = await (
                await (
                    await hre.ethers.getContractFactory('TapiocaWrapper')
                ).deploy(signer.address)
            ).deployed();

            await expect(
                tapiocaWrapper.lastTOFT(),
            ).to.be.revertedWithCustomError(
                tapiocaWrapper,
                'TapiocaWrapper__NoTOFTDeployed',
            );
        });

        it('Should return the length of the last TOFT deployed', async () => {
            const {
                signer,
                tapiocaWrapper_0,
                erc20Mock1,
                erc20Mock2,
                LZEndpointMock_chainID_0,
                utils: { Tx_deployTapiocaOFT },
            } = await loadFixture(setupFixture);

            const erc20Address1 = erc20Mock1.address;
            const erc20Address2 = erc20Mock2.address;

            const Cluster = new Cluster__factory(signer);
            const cluster = await Cluster.deploy(1);

            const { txData: bytecode1 } = await Tx_deployTapiocaOFT(
                LZEndpointMock_chainID_0.address,
                erc20Address1,
                ethers.constants.AddressZero,
                cluster.address,
                0,
                signer,
            );
            const { txData: bytecode2 } = await Tx_deployTapiocaOFT(
                LZEndpointMock_chainID_0.address,
                erc20Address2,
                ethers.constants.AddressZero,
                cluster.address,
                0,
                signer,
            );

            await tapiocaWrapper_0.createTOFT(
                erc20Address1,
                bytecode1,
                generateSalt(),
                false,
            );

            const toft1 = await ethers.getContractAt(
                'TapiocaOFT',
                await tapiocaWrapper_0.lastTOFT(),
            );
            expect(await toft1.erc20()).to.eq(erc20Address1);

            await tapiocaWrapper_0.createTOFT(
                erc20Address2,
                bytecode2,
                generateSalt(),
                false,
            );

            const toft2 = await ethers.getContractAt(
                'TapiocaOFT',
                await tapiocaWrapper_0.lastTOFT(),
            );
            expect(await toft2.erc20()).to.eq(erc20Address2);
        });
    });

    describe('executeTOFT()', () => {
        it('Should be only owner', async () => {
            const {
                tapiocaWrapper_0,
                tapiocaOFT0,
                utils: { newEOA },
            } = await loadFixture(setupFixture);
            const eoa = newEOA();
            await setBalance(eoa.address, ethers.utils.parseEther('100000'));

            await expect(
                tapiocaWrapper_0
                    .connect(eoa)
                    .executeTOFT(
                        tapiocaOFT0.address,
                        ethers.utils.randomBytes(32),
                        true,
                    ),
            ).to.be.revertedWith('Ownable: caller is not the owner');
        });

        it('Should revert on failure', async () => {
            const { tapiocaWrapper_0, tapiocaOFT0 } = await loadFixture(
                setupFixture,
            );

            await expect(
                tapiocaWrapper_0.executeTOFT(
                    tapiocaOFT0.address,
                    ethers.utils.randomBytes(32),
                    true,
                ),
            ).to.be.revertedWithCustomError(
                tapiocaWrapper_0,
                'TapiocaWrapper__TOFTExecutionFailed',
            );

            await expect(
                tapiocaWrapper_0.executeTOFT(
                    tapiocaOFT0.address,
                    ethers.utils.randomBytes(32),
                    false,
                ),
            ).to.not.be.reverted;
        });

        it('Should execute the change in trusted remote for a TOFT successfully ', async () => {
            const { tapiocaWrapper_0, tapiocaOFT0 } = await loadFixture(
                setupFixture,
            );
            const [chainID, address] = [
                200,
                '0x00000000000000000000000000000000000000ff',
            ];
            const txData = tapiocaOFT0.interface.encodeFunctionData(
                'setTrustedRemote',
                [chainID, address],
            );
            await expect(
                tapiocaWrapper_0.executeTOFT(tapiocaOFT0.address, txData, true),
            ).to.not.be.reverted;
            expect(await tapiocaOFT0.trustedRemoteLookup(chainID)).to.eq(
                address,
            );
        });
    });
});
