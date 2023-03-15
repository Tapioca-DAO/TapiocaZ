import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { typechain } from 'tapioca-sdk';
import { STARGATE_ROUTERS } from '../constants';

export const deployBalancer__task = async (
    taskArgs: { overwrite?: boolean; tag?: string },
    hre: HardhatRuntimeEnvironment,
) => {
    console.log('[+] Deploying Balancer...');

    const { overwrite, tag } = taskArgs;

    const signer = (await hre.ethers.getSigners())[0];
    const chainId = String(hre.network.config.chainId);

    // Check if already deployed
    const prevDeployment = hre.SDK.db.getLocalDeployment(
        chainId,
        'Balancer',
        tag,
    );
    if (prevDeployment && !overwrite) {
        console.log(
            `[-] Balancer already deployed on ${hre.network.name} at ${prevDeployment.address}`,
        );
        return;
    }

    // Check if stargate router exists
    const stargateObj =
        STARGATE_ROUTERS[chainId as keyof typeof STARGATE_ROUTERS];
    if (!stargateObj) {
        throw new Error(`[-] No stargate router found for chainId ${chainId}`);
    }

    const balancer = await hre.ethers.getContractFactory('Balancer');

    const deployerVM = new hre.SDK.DeployerVM(hre, {
        bytecodeSizeLimit: 90_000,
        multicall: typechain.Multicall.Multicall3__factory.connect(
            hre.SDK.config.MULTICALL_ADDRESS,
            hre.ethers.provider,
        ),
        tag,
    });

    deployerVM.add({
        contract: balancer,
        args: [stargateObj.routerETH, stargateObj.router, signer.address],
        deploymentName: 'TapiocaWrapper',
    });
    await deployerVM.execute(3);
    deployerVM.save();
    await deployerVM.verify();
};