import { IDependentOn } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { TOFTGenericReceiverModule__factory } from '@typechain/index';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';

export const buildTOFTGenericReceiverModule = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TOFTGenericReceiverModule__factory['deploy']>,
    dependsOn: IDependentOn[],
): Promise<IDeployerVMAdd<TOFTGenericReceiverModule__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory(
            'TOFTGenericReceiverModule',
        ),
        deploymentName,
        args,
        dependsOn,
    };
};
