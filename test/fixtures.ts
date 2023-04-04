import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumberish, ethers } from 'ethers';
import hre from 'hardhat';
import { BaseTOFT, ERC20Mock, MTapiocaOFT, TapiocaOFT } from '../typechain';
import { register } from './test.utils';

export const setupFixture = async () => {
    const signer = (await hre.ethers.getSigners())[0];
    const randomUser = new ethers.Wallet(
        ethers.Wallet.createRandom().privateKey,
        hre.ethers.provider,
    );
    await hre.ethers.provider.send('hardhat_setBalance', [
        randomUser.address,
        ethers.utils.hexStripZeros(ethers.utils.parseEther(String(10))._hex),
    ]);

    const erc20Mock = await (
        await hre.ethers.getContractFactory('ERC20Mock')
    ).deploy('erc20Mock', 'MOCK');
    const erc20Mock1 = await (
        await hre.ethers.getContractFactory('ERC20Mock')
    ).deploy('erc20Mock', 'MOCK');
    const erc20Mock2 = await (
        await hre.ethers.getContractFactory('ERC20Mock')
    ).deploy('erc20Mock', 'MOCK');

    const mErc20Mock = await (
        await hre.ethers.getContractFactory('ERC20Mock')
    ).deploy('erc20Mock', 'MOCK');
    const mErc20Mock2 = await (
        await hre.ethers.getContractFactory('ERC20Mock')
    ).deploy('erc20Mock', 'MOCK');

    const stargateRouterMock = await (
        await hre.ethers.getContractFactory('StargateRouterMock')
    ).deploy(mErc20Mock.address);

    const stargateRouterETHMock = await (
        await hre.ethers.getContractFactory('StargateRouterETHMock')
    ).deploy(stargateRouterMock.address, mErc20Mock.address);

    const balancer = await (
        await hre.ethers.getContractFactory('Balancer')
    ).deploy(
        stargateRouterETHMock.address, //routerETH 0x150f94b44927f078737562f0fcf3c95c01cc2376
        stargateRouterMock.address, //router 0x8731d54e9d02c286767d56ac03e8037c07e01e98
        signer.address,
    );

    const {
        LZEndpointMock_chainID_0,
        LZEndpointMock_chainID_10,
        tapiocaWrapper_0,
        tapiocaWrapper_10,
        YieldBox_0,
        YieldBox_10,
        utils,
    } = await register(hre);

    //Deploy mTapiocaOFT0
    {
        const txData = await tapiocaWrapper_0.populateTransaction.createTOFT(
            mErc20Mock.address,
            (
                await utils.Tx_deployTapiocaOFT(
                    LZEndpointMock_chainID_0.address,
                    false,
                    mErc20Mock.address,
                    YieldBox_0.address,
                    31337, //hardhat network
                    signer,
                    true,
                )
            ).txData,
            hre.ethers.utils.randomBytes(32),
            true,
        );
        txData.gasLimit = await hre.ethers.provider.estimateGas(txData);
        await signer.sendTransaction(txData);
    }
    const mtapiocaOFT0 = (await utils.attachTapiocaOFT(
        await tapiocaWrapper_0.tapiocaOFTs(
            (await tapiocaWrapper_0.tapiocaOFTLength()).sub(1),
        ),
        true,
    )) as MTapiocaOFT;

    // Deploy mTapiocaOFT10
    {
        const txData = await tapiocaWrapper_10.populateTransaction.createTOFT(
            mErc20Mock.address,
            (
                await utils.Tx_deployTapiocaOFT(
                    LZEndpointMock_chainID_10.address,
                    false,
                    mErc20Mock.address,
                    YieldBox_10.address,
                    10,
                    signer,
                    true,
                )
            ).txData,
            hre.ethers.utils.randomBytes(32),
            true,
        );
        txData.gasLimit = await hre.ethers.provider.estimateGas(txData);
        await signer.sendTransaction(txData);
    }
    const mtapiocaOFT10 = (await utils.attachTapiocaOFT(
        await tapiocaWrapper_10.tapiocaOFTs(
            (await tapiocaWrapper_10.tapiocaOFTLength()).sub(1),
        ),
        true,
    )) as MTapiocaOFT;

    // Deploy TapiocaOFT0
    {
        const txData = await tapiocaWrapper_0.populateTransaction.createTOFT(
            erc20Mock.address,
            (
                await utils.Tx_deployTapiocaOFT(
                    LZEndpointMock_chainID_0.address,
                    false,
                    erc20Mock.address,
                    YieldBox_0.address,
                    31337, //hardhat network
                    signer,
                )
            ).txData,
            hre.ethers.utils.randomBytes(32),
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
        const txData = await tapiocaWrapper_10.populateTransaction.createTOFT(
            erc20Mock.address,
            (
                await utils.Tx_deployTapiocaOFT(
                    LZEndpointMock_chainID_10.address,
                    false,
                    erc20Mock.address,
                    YieldBox_10.address,
                    10,
                    signer,
                )
            ).txData,
            hre.ethers.utils.randomBytes(32),
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

    // Link endpoints with addresses
    LZEndpointMock_chainID_0.setDestLzEndpoint(
        tapiocaOFT10.address,
        LZEndpointMock_chainID_10.address,
    );
    LZEndpointMock_chainID_10.setDestLzEndpoint(
        tapiocaOFT0.address,
        LZEndpointMock_chainID_0.address,
    );

    // Link endpoints with addresses
    LZEndpointMock_chainID_0.setDestLzEndpoint(
        mtapiocaOFT10.address,
        LZEndpointMock_chainID_10.address,
    );
    LZEndpointMock_chainID_10.setDestLzEndpoint(
        mtapiocaOFT0.address,
        LZEndpointMock_chainID_0.address,
    );

    const dummyAmount = ethers.BigNumber.from(1e5);
    const bigDummyAmount = ethers.utils.parseEther('10');

    const mintAndApprove = async (
        erc20Mock: ERC20Mock,
        toft: BaseTOFT,
        signer: SignerWithAddress,
        amount: BigNumberish,
    ) => {
        await erc20Mock.mint(signer.address, amount);
        await erc20Mock.approve(toft.address, amount);
    };
    const vars = {
        signer,
        randomUser,
        LZEndpointMock_chainID_0,
        LZEndpointMock_chainID_10,
        tapiocaWrapper_0,
        tapiocaWrapper_10,
        erc20Mock,
        erc20Mock1,
        erc20Mock2,
        mErc20Mock,
        mErc20Mock2,
        tapiocaOFT0,
        tapiocaOFT10,
        dummyAmount,
        bigDummyAmount,
        YieldBox_0,
        YieldBox_10,
        mtapiocaOFT0,
        mtapiocaOFT10,
        balancer,
        stargateRouterMock,
        stargateRouterETHMock,
    };
    const functions = {
        mintAndApprove,
        utils,
    };

    return { ...vars, ...functions };
};
