import { TOFTVault__factory } from '@typechain/index';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';

export const buildToftVault = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TOFTVault__factory['deploy']>,
): Promise<IDeployerVMAdd<TOFTVault__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory('TOFTVault'),
        deploymentName,
        args,
        dependsOn: [],
    };
};
