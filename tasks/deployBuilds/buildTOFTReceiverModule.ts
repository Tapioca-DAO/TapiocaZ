import { TOFTReceiver__factory } from '@typechain/index';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';

export const buildTOFTReceiverModule = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TOFTReceiver__factory['deploy']>,
): Promise<IDeployerVMAdd<TOFTReceiver__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory('TOFTReceiver'),
        deploymentName,
        args,
        dependsOn: [],
    };
};
