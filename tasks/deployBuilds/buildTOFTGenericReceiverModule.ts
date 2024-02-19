import { TOFTGenericReceiverModule__factory } from '@typechain/index';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';

export const buildTOFTGenericReceiverModule = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TOFTGenericReceiverModule__factory['deploy']>,
): Promise<IDeployerVMAdd<TOFTGenericReceiverModule__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory(
            'buildTOFTGenericReceiverModule',
        ),
        deploymentName,
        args,
        dependsOn: [],
    };
};
