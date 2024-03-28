import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { IDependentOn } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { MTOFT__factory } from '@typechain/index';

export const buildMTOFT = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<MTOFT__factory['deploy']>,
    dependsOn: IDependentOn[],
): Promise<IDeployerVMAdd<MTOFT__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory('MTOFT'),
        deploymentName,
        args,
        dependsOn,
    };
};
