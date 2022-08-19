import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumberish, ethers } from 'ethers';
import hre from 'hardhat';
import { BN } from '../scripts/utils';
import { ERC20Mock, TapiocaOFT } from '../typechain';
import { register } from './test.utils';

export const setupFixture = async () => {
    const signer = (await hre.ethers.getSigners())[0];

    const erc20Mock = await (
        await hre.ethers.getContractFactory('ERC20Mock')
    ).deploy('erc20Mock', 'MOCK');
    const erc20Mock1 = await (
        await hre.ethers.getContractFactory('ERC20Mock')
    ).deploy('erc20Mock', 'MOCK');

    const {
        LZEndpointMock_chainID_0,
        LZEndpointMock_chainID_10,
        tapiocaWrapper,
        utils,
    } = await register(hre);

    await tapiocaWrapper.setMngmtFee(25); // 0.25%

    // Deploy TapiocaOFT0
    await tapiocaWrapper.createTOFT(
        erc20Mock.address,
        (
            await utils.Tx_deployTapiocaOFT(
                LZEndpointMock_chainID_0.address,
                erc20Mock.address,
                0,
                signer,
            )
        ).txData,
        hre.ethers.utils.randomBytes(32),
    );

    const tapiocaOFT0 = (await utils.attachTapiocaOFT(
        await tapiocaWrapper.tapiocaOFTs(
            (await tapiocaWrapper.tapiocaOFTLength()).sub(1),
        ),
    )) as TapiocaOFT;

    // Deploy TapiocaOFT10
    await tapiocaWrapper.createTOFT(
        erc20Mock.address,
        (
            await utils.Tx_deployTapiocaOFT(
                LZEndpointMock_chainID_10.address,
                erc20Mock.address,
                0,
                signer,
            )
        ).txData,
        hre.ethers.utils.randomBytes(32),
    );

    const tapiocaOFT10 = (await utils.attachTapiocaOFT(
        await tapiocaWrapper.tapiocaOFTs(
            (await tapiocaWrapper.tapiocaOFTLength()).sub(1),
        ),
    )) as TapiocaOFT;

    // Link endpoints with addresses
    LZEndpointMock_chainID_0.setDestLzEndpoint(
        tapiocaOFT10.address,
        LZEndpointMock_chainID_10.address,
    );
    LZEndpointMock_chainID_10.setDestLzEndpoint(
        tapiocaOFT0.address,
        LZEndpointMock_chainID_0.address,
    );

    const dummyAmount = ethers.BigNumber.from(1e5);

    const estimateFees = async (amount: BigNumberish) =>
        await tapiocaOFT0.estimateFees(
            await tapiocaWrapper.mngmtFee(),
            await tapiocaWrapper.mngmtFeeFraction(),
            amount,
        );

    const mintAndApprove = async (
        erc20Mock: ERC20Mock,
        toft: TapiocaOFT,
        signer: SignerWithAddress,
        amount: BigNumberish,
    ) => {
        const fees = await estimateFees(amount);
        const amountWithFees = BN(amount).add(fees);

        await erc20Mock.mint(signer.address, amountWithFees);
        await erc20Mock.approve(toft.address, amountWithFees);
    };
    const vars = {
        signer,
        LZEndpointMock_chainID_0,
        LZEndpointMock_chainID_10,
        tapiocaWrapper,
        erc20Mock,
        erc20Mock1,
        tapiocaOFT0,
        tapiocaOFT10,
        dummyAmount,
    };
    const functions = {
        estimateFees,
        mintAndApprove,
        utils,
    };

    return { ...vars, ...functions };
};
