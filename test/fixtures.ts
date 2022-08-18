import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumberish, ethers } from 'ethers';
import hre from 'hardhat';
import { BN } from '../scripts/utils';
import { ERC20Mock, TapiocaOFTMock } from '../typechain';
import { register } from './test.utils';

export const setupFixture = async () => {
    const signer = (await hre.ethers.getSigners())[0];

    const erc20Mock = await (
        await hre.ethers.getContractFactory('ERC20Mock')
    ).deploy('erc20Mock', 'MOCK');
    const erc20Mock1 = await (
        await hre.ethers.getContractFactory('ERC20Mock')
    ).deploy('erc20Mock', 'MOCK');

    const { LZEndpointMock0, LZEndpointMock1, tapiocaWrapper, utils } =
        await register(hre);

    await tapiocaWrapper.setMngmtFee(25); // 0.25%

    // Deploy TapiocaOFT0
    await tapiocaWrapper.createTOFT(
        erc20Mock.address,
        (
            await utils.Tx_deployTapiocaOFT(
                LZEndpointMock0.address,
                erc20Mock.address,
                0,
                signer,
                0,
            )
        ).txData,
        hre.ethers.utils.randomBytes(32),
    );

    const tapiocaOFT0 = (await utils.attachTapiocaOFT(
        await tapiocaWrapper.tapiocaOFTs(
            (await tapiocaWrapper.tapiocaOFTLength()).sub(1),
        ),
    )) as TapiocaOFTMock;

    // Deploy TapiocaOFT10
    await tapiocaWrapper.createTOFT(
        erc20Mock.address,
        (
            await utils.Tx_deployTapiocaOFT(
                LZEndpointMock1.address,
                erc20Mock.address,
                0,
                signer,
                10,
            )
        ).txData,
        hre.ethers.utils.randomBytes(32),
    );

    const tapiocaOFT10 = (await utils.attachTapiocaOFT(
        await tapiocaWrapper.tapiocaOFTs(
            (await tapiocaWrapper.tapiocaOFTLength()).sub(1),
        ),
    )) as TapiocaOFTMock;

    // Link endpoints with addresses
    LZEndpointMock0.setDestLzEndpoint(
        tapiocaOFT10.address,
        LZEndpointMock1.address,
    );
    LZEndpointMock1.setDestLzEndpoint(
        tapiocaOFT0.address,
        LZEndpointMock0.address,
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
        toft: TapiocaOFTMock,
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
        LZEndpointMock0,
        LZEndpointMock1,
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
