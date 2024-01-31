import { TOFTSender__factory } from '@typechain/index';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';

export const buildTOFTSenderModule = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TOFTSender__factory['deploy']>,
): Promise<IDeployerVMAdd<TOFTSender__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory('TOFTSender'),
        deploymentName,
        args,
        dependsOn: [],
    };
};
