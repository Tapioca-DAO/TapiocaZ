import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { useUtils } from '../scripts/utils';
import hre, { ethers, network } from 'hardhat';
import { time } from '@nomicfoundation/hardhat-network-helpers';
import { MTapiocaOFT } from 'tapioca-sdk/dist/typechain/tapiocaz';
import { Cluster__factory } from '../gitsub_tapioca-sdk/src/typechain/tapioca-periphery';

export const register = async (hre: HardhatRuntimeEnvironment) => {
    const { ethers } = hre;
    const signer = (await ethers.getSigners())[0];

    const { deployLZEndpointMock, deployTapiocaWrapper, deployYieldBoxMock } =
        useUtils(hre, signer);

    const utils = useUtils(hre, signer);
    return {
        signer,
        LZEndpointMock_chainID_0: await deployLZEndpointMock(0),
        LZEndpointMock_chainID_10: await deployLZEndpointMock(10),
        tapiocaWrapper_0: await deployTapiocaWrapper(),
        tapiocaWrapper_10: await deployTapiocaWrapper(),
        YieldBox_0: await deployYieldBoxMock(),
        YieldBox_10: await deployYieldBoxMock(),
        utils,
    };
};

export async function setBalance(addr: string, ether: number) {
    await ethers.provider.send('hardhat_setBalance', [
        addr,
        ethers.utils.hexStripZeros(ethers.utils.parseEther(String(ether))._hex),
    ]);
}

export async function impersonateAccount(address: string) {
    return network.provider.request({
        method: 'hardhat_impersonateAccount',
        params: [address],
    });
}
export async function registerFork() {
    await impersonateAccount(process.env.BINANCE_WALLET_ADDRESS!);
    const binanceWallet = await ethers.getSigner(
        process.env.BINANCE_WALLET_ADDRESS!,
    );

    /**
     * INITIAL SETUP
     */
    const deployer = (await ethers.getSigners())[0];

    const eoa1 = new ethers.Wallet(
        ethers.Wallet.createRandom().privateKey,
        ethers.provider,
    );
    await setBalance(eoa1.address, 100000);

    const {
        deployYieldBoxMock,
        deployTapiocaWrapper,
        Tx_deployTapiocaOFT,
        attachTapiocaOFT,
    } = useUtils(hre, deployer);

    const yieldBox = await deployYieldBoxMock();
    const tapiocaWrapper1 = await deployTapiocaWrapper();
    const tapiocaWrapper2 = await deployTapiocaWrapper();

    const balancer = await (
        await hre.ethers.getContractFactory('Balancer')
    ).deploy(
        process.env.STARGATE_ROUTER_ETH!, // stargateRouterETHMock.address, //routerETH 0x150f94b44927f078737562f0fcf3c95c01cc2376
        process.env.STARGATE_ROUTER!, //stargateRouterMock.address, //router 0x8731d54e9d02c286767d56ac03e8037c07e01e98
        deployer.address,
    );

    const Cluster = new Cluster__factory(deployer);
    const cluster = await Cluster.deploy(process.env.LZ_ENDPOINT!);

    //Deploy mtOft1
    {
        const txData = await tapiocaWrapper1.populateTransaction.createTOFT(
            ethers.constants.AddressZero,
            (
                await Tx_deployTapiocaOFT(
                    process.env.LZ_ENDPOINT!,
                    ethers.constants.AddressZero, //gas token
                    yieldBox.address,
                    cluster.address,
                    1,
                    deployer,
                    true,
                )
            ).txData,
            hre.ethers.utils.randomBytes(32),
            true,
        );
        txData.gasLimit = await hre.ethers.provider.estimateGas(txData);
        await deployer.sendTransaction(txData);
    }
    const tOft1 = (await attachTapiocaOFT(
        await tapiocaWrapper1.tapiocaOFTs(
            (await tapiocaWrapper1.tapiocaOFTLength()).sub(1),
        ),
        true,
    )) as MTapiocaOFT;

    //Deploy mtOft2
    {
        const txData = await tapiocaWrapper2.populateTransaction.createTOFT(
            ethers.constants.AddressZero,
            (
                await Tx_deployTapiocaOFT(
                    process.env.LZ_ENDPOINT!,
                    ethers.constants.AddressZero, //gas token
                    yieldBox.address,
                    cluster.address,
                    1,
                    deployer,
                    true,
                )
            ).txData,
            hre.ethers.utils.randomBytes(32),
            true,
        );
        txData.gasLimit = await hre.ethers.provider.estimateGas(txData);
        await deployer.sendTransaction(txData);
    }
    const tOft2 = (await attachTapiocaOFT(
        await tapiocaWrapper2.tapiocaOFTs(
            (await tapiocaWrapper2.tapiocaOFTLength()).sub(1),
        ),
        true,
    )) as MTapiocaOFT;

    return {
        deployer,
        yieldBox,
        tapiocaWrapper1,
        tapiocaWrapper2,
        tOft1,
        tOft2,
        balancer,
    };
}
