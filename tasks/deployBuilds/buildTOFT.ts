import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { IDependentOn } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { TOFT__factory } from '@typechain/index';

export const buildTOFT = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TOFT__factory['deploy']>,
    dependsOn: IDependentOn[],
): Promise<IDeployerVMAdd<TOFT__factory>> => {
    return {
        contract: (await hre.ethers.getContractFactory(
            'TOFT',
        )) as TOFT__factory,
        deploymentName,
        args,
        dependsOn,
    };
};
