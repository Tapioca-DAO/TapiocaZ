import { TOFTHelper__factory } from '@typechain/index';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';

export const buildToftHelper = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
): Promise<IDeployerVMAdd<TOFTHelper__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory('TOFTHelper'),
        deploymentName,
        args: [],
    };
};
