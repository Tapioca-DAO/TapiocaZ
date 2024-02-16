import { TOFTOptionsReceiverModule__factory } from '@typechain/index';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';

export const buildTOFTOptionsReceiverModule = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TOFTOptionsReceiverModule__factory['deploy']>,
): Promise<IDeployerVMAdd<TOFTOptionsReceiverModule__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory(
            'TOFTOptionsReceiverModule',
        ),
        deploymentName,
        args,
        dependsOn: [],
    };
};
