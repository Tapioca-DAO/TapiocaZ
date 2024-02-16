import { TOFTMarketReceiverModule__factory } from '@typechain/index';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';

export const buildTOFTMarketReceiverModule = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TOFTMarketReceiverModule__factory['deploy']>,
): Promise<IDeployerVMAdd<TOFTMarketReceiverModule__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory(
            'TOFTMarketReceiverModule',
        ),
        deploymentName,
        args,
        dependsOn: [],
    };
};
