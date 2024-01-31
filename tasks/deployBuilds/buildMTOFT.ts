import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { IDependentOn } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { mTOFT__factory } from '@typechain/index';

export const buildMTOFT = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<mTOFT__factory['deploy']>,
    dependsOn: IDependentOn[],
): Promise<IDeployerVMAdd<mTOFT__factory>> => {
    return {
        contract: (await hre.ethers.getContractFactory(
            'mTOFT',
        )) as mTOFT__factory,
        deploymentName,
        args,
        dependsOn,
    };
};
