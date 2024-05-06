import { Balancer__factory } from '@typechain/index';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';

export const buildBalancer = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<Balancer__factory['deploy']>,
): Promise<IDeployerVMAdd<Balancer__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory('Balancer'),
        deploymentName,
        args,
        dependsOn: [],
    };
};
