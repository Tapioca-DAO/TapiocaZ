import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { useUtils } from '../scripts/utils';
import hre, { ethers, network } from 'hardhat';
import { time } from '@nomicfoundation/hardhat-network-helpers';
import { MTapiocaOFT } from 'tapioca-sdk/dist/typechain/tapiocaz';
import { Cluster__factory } from '@tapioca-sdk/typechain/tapioca-periphery';

export const register = async (hre: HardhatRuntimeEnvironment) => {
    const { ethers } = hre;
    const signer = (await ethers.getSigners())[0];

    const { deployYieldBoxMock } = useUtils(hre, signer);

    const utils = useUtils(hre, signer);
    return {
        signer,
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

    const { deployYieldBoxMock } = useUtils(hre, deployer);

    const yieldBox = await deployYieldBoxMock();

    const balancer = await (
        await hre.ethers.getContractFactory('Balancer')
    ).deploy(
        process.env.STARGATE_ROUTER_ETH!, // stargateRouterETHMock.address, //routerETH 0x150f94b44927f078737562f0fcf3c95c01cc2376
        process.env.STARGATE_ROUTER!, //stargateRouterMock.address, //router 0x8731d54e9d02c286767d56ac03e8037c07e01e98
        deployer.address,
    );

    const Cluster = new Cluster__factory(deployer);
    const cluster = await Cluster.deploy(
        process.env.LZ_ENDPOINT!,
        deployer.address,
    );

    return {
        deployer,
        yieldBox,
        balancer,
    };
}
