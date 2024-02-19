import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumberish, ethers } from 'ethers';
import hre from 'hardhat';

import { register } from './test.utils';
import { time } from '@nomicfoundation/hardhat-network-helpers';

import {
    ERC20Mock__factory,
    ERC20Mock,
    StargateRouterMock__factory,
    StargateRouterETHMock__factory,
} from '@tapioca-sdk/typechain/tapioca-mocks';

import {
    LZEndpointMock__factory,
    YieldBoxMock__factory,
} from '@tapioca-sdk/typechain/tapioca-mocks';

import { Cluster__factory } from '@tapioca-sdk/typechain/tapioca-periphery';
import { TOFTVault__factory } from '@typechain/index';

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

    const ERC20Mock = new ERC20Mock__factory(signer);

    const erc20Mock = await ERC20Mock.deploy(
        'erc20Mock',
        'MOCK',
        0,
        18,
        signer.address,
    );
    await erc20Mock.updateMintLimit(ethers.constants.MaxUint256);

    const erc20Mock1 = await ERC20Mock.deploy(
        'erc20Mock',
        'MOCK',
        0,
        18,
        signer.address,
    );
    await erc20Mock1.updateMintLimit(ethers.constants.MaxUint256);

    const erc20Mock2 = await ERC20Mock.deploy(
        'erc20Mock',
        'MOCK',
        0,
        18,
        signer.address,
    );
    await erc20Mock2.updateMintLimit(ethers.constants.MaxUint256);

    const mErc20Mock = await ERC20Mock.deploy(
        'erc20Mock',
        'MOCK',
        0,
        18,
        signer.address,
    );
    await mErc20Mock.updateMintLimit(ethers.constants.MaxUint256);

    const mErc20Mock2 = await ERC20Mock.deploy(
        'erc20Mock',
        'MOCK',
        0,
        18,
        signer.address,
    );
    await mErc20Mock2.updateMintLimit(ethers.constants.MaxUint256);

    const StargateRouterMock = new StargateRouterMock__factory(signer);
    const stargateRouterMock = await StargateRouterMock.deploy(
        mErc20Mock.address,
    );

    const StargateRouterETHMock = new StargateRouterETHMock__factory(signer);
    const stargateRouterETHMock = await StargateRouterETHMock.deploy(
        stargateRouterMock.address,
        mErc20Mock.address,
    );

    const balancer = await (
        await hre.ethers.getContractFactory('Balancer')
    ).deploy(
        stargateRouterETHMock.address, //routerETH 0x150f94b44927f078737562f0fcf3c95c01cc2376
        stargateRouterMock.address, //router 0x8731d54e9d02c286767d56ac03e8037c07e01e98
        signer.address,
    );

    const { YieldBox_0, YieldBox_10, utils } = await register(hre);

    const Cluster = new Cluster__factory(signer);
    const Cluster_0 = await Cluster.deploy(31337, signer.address);
    const Cluster_10 = await Cluster.deploy(10, signer.address);

    const LZEndpointMock = new LZEndpointMock__factory(signer);
    const lzEndpoint0 = await LZEndpointMock.deploy(31337);
    const lzEndpoint10 = await LZEndpointMock.deploy(10);

    const mToftFactory = await hre.ethers.getContractFactory('mTOFT');
    const toftFactory = await hre.ethers.getContractFactory('TOFT');

    const vaultFactory = new TOFTVault__factory(signer);

    //Deploy mTapiocaOFT0
    const vault0 = await vaultFactory.deploy(mErc20Mock.address);
    let initStruct0 = {
        name: 'mtapiocaOFT0',
        symbol: 'mt0',
        endpoint: lzEndpoint0.address,
        delegate: signer.address,
        yieldBox: YieldBox_0.address,
        cluster: Cluster_0.address,
        erc20: mErc20Mock.address,
        vault: vault0.address,
        hostEid: 31337,
        extExec: hre.ethers.constants.AddressZero,
    };
    const mtoftSender0 = await (
        await hre.ethers.getContractFactory('TOFTSender')
    ).deploy(initStruct0);
    const mtoftReceiver0 = await (
        await hre.ethers.getContractFactory('TOFTReceiver')
    ).deploy(initStruct0);
    const mtoftGenericReceiver0 = await (
        await hre.ethers.getContractFactory('TOFTGenericReceiverModule')
    ).deploy(initStruct0);
    const mtoftMarketReceiver0 = await (
        await hre.ethers.getContractFactory('TOFTMarketReceiverModule')
    ).deploy(initStruct0);
    const mtoftOptionsReceiver0 = await (
        await hre.ethers.getContractFactory('TOFTOptionsReceiverModule')
    ).deploy(initStruct0);
    const mtapiocaOFT0 = await mToftFactory.deploy(
        initStruct0,
        {
            tOFTSenderModule: mtoftSender0.address,
            tOFTReceiverModule: mtoftReceiver0.address,
            marketReceiverModule: mtoftMarketReceiver0.address,
            optionsReceiverModule: mtoftOptionsReceiver0.address,
            genericReceiverModule: mtoftGenericReceiver0.address,
        },
        hre.ethers.constants.AddressZero,
    );
    await mtapiocaOFT0.deployed();

    const ownerStateData = {
        stargateRouter: hre.ethers.constants.AddressZero,
        mintFee: 0,
        mintCap: 0,
        connectedChain: 0,
        connectedChainState: false,
        balancerStateAddress: hre.ethers.constants.AddressZero,
        balancerState: false,
    };
    await mtapiocaOFT0.setOwnerState(ownerStateData);

    // Deploy mTapiocaOFT10
    const vault10 = await vaultFactory.deploy(mErc20Mock.address);
    let initStruct10 = {
        name: 'mtapiocaOFT10',
        symbol: 'mt10',
        endpoint: lzEndpoint10.address,
        delegate: signer.address,
        yieldBox: YieldBox_0.address,
        cluster: Cluster_0.address,
        erc20: mErc20Mock.address,
        vault: vault10.address,
        hostEid: 10,
        extExec: hre.ethers.constants.AddressZero,
    };
    const mtoftSender10 = await (
        await hre.ethers.getContractFactory('TOFTSender')
    ).deploy(initStruct10);
    const mtoftReceiver10 = await (
        await hre.ethers.getContractFactory('TOFTReceiver')
    ).deploy(initStruct10);
    const mtoftGenericReceiver10 = await (
        await hre.ethers.getContractFactory('TOFTGenericReceiverModule')
    ).deploy(initStruct10);
    const mtoftMarketReceiver10 = await (
        await hre.ethers.getContractFactory('TOFTMarketReceiverModule')
    ).deploy(initStruct10);
    const mtoftOptionsReceiver10 = await (
        await hre.ethers.getContractFactory('TOFTOptionsReceiverModule')
    ).deploy(initStruct10);
    const mtapiocaOFT10 = await mToftFactory.deploy(
        initStruct10,
        {
            tOFTSenderModule: mtoftSender10.address,
            tOFTReceiverModule: mtoftReceiver10.address,
            marketReceiverModule: mtoftMarketReceiver10.address,
            optionsReceiverModule: mtoftOptionsReceiver10.address,
            genericReceiverModule: mtoftGenericReceiver10.address,
        },
        hre.ethers.constants.AddressZero,
    );
    await mtapiocaOFT0.deployed();

    await mtapiocaOFT10.setOwnerState(ownerStateData);

    // Deploy TapiocaOFT0
    const vault00 = await vaultFactory.deploy(erc20Mock.address);
    initStruct0 = {
        name: 'tapiocaOFT0',
        symbol: 't0',
        endpoint: lzEndpoint0.address,
        delegate: signer.address,
        yieldBox: YieldBox_0.address,
        cluster: Cluster_0.address,
        erc20: erc20Mock.address,
        vault: vault00.address,
        hostEid: 31337,
        extExec: hre.ethers.constants.AddressZero,
    };
    const toftSender0 = await (
        await hre.ethers.getContractFactory('TOFTSender')
    ).deploy(initStruct0);
    const toftReceiver0 = await (
        await hre.ethers.getContractFactory('TOFTReceiver')
    ).deploy(initStruct0);
    const toftGenericReceiver0 = await (
        await hre.ethers.getContractFactory('TOFTGenericReceiverModule')
    ).deploy(initStruct0);
    const toftMarketReceiver0 = await (
        await hre.ethers.getContractFactory('TOFTMarketReceiverModule')
    ).deploy(initStruct0);
    const toftOptionsReceiver0 = await (
        await hre.ethers.getContractFactory('TOFTOptionsReceiverModule')
    ).deploy(initStruct0);
    const tapiocaOFT0 = await toftFactory.deploy(initStruct0, {
        tOFTSenderModule: toftSender0.address,
        tOFTReceiverModule: toftReceiver0.address,
        marketReceiverModule: toftMarketReceiver0.address,
        optionsReceiverModule: toftOptionsReceiver0.address,
        genericReceiverModule: toftGenericReceiver0.address,
    });
    await tapiocaOFT0.deployed();

    // Deploy TapiocaOFT10
    const vault1010 = await vaultFactory.deploy(erc20Mock.address);
    initStruct10 = {
        name: 'tapiocaOFT10',
        symbol: 't10',
        endpoint: lzEndpoint10.address,
        delegate: signer.address,
        yieldBox: YieldBox_10.address,
        cluster: Cluster_10.address,
        erc20: erc20Mock.address,
        vault: vault1010.address,
        hostEid: 10,
        extExec: hre.ethers.constants.AddressZero,
    };
    const toftSender10 = await (
        await hre.ethers.getContractFactory('TOFTSender')
    ).deploy(initStruct10);
    const toftReceiver10 = await (
        await hre.ethers.getContractFactory('TOFTReceiver')
    ).deploy(initStruct10);
    const toftGenericReceiver10 = await (
        await hre.ethers.getContractFactory('TOFTGenericReceiverModule')
    ).deploy(initStruct10);
    const toftMarketReceiver10 = await (
        await hre.ethers.getContractFactory('TOFTMarketReceiverModule')
    ).deploy(initStruct10);
    const toftOptionsReceiver10 = await (
        await hre.ethers.getContractFactory('TOFTOptionsReceiverModule')
    ).deploy(initStruct10);
    const tapiocaOFT10 = await toftFactory.deploy(initStruct10, {
        tOFTSenderModule: toftSender10.address,
        tOFTReceiverModule: toftReceiver10.address,
        marketReceiverModule: toftMarketReceiver10.address,
        optionsReceiverModule: toftOptionsReceiver10.address,
        genericReceiverModule: toftGenericReceiver10.address,
    });
    await tapiocaOFT10.deployed();

    const dummyAmount = ethers.BigNumber.from(1e5);
    const bigDummyAmount = ethers.utils.parseEther('10');

    const mintAndApprove = async (
        erc20Mock: ERC20Mock,
        toft: BaseTOFT,
        signer: SignerWithAddress,
        amount: BigNumberish,
    ) => {
        await time.increase(86401);
        await erc20Mock.freeMint(amount);
        await erc20Mock.approve(toft.address, amount);
    };
    const vars = {
        signer,
        randomUser,
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
