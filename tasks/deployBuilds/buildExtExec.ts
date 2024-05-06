import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { IDeployerVMAdd } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { IDependentOn } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { TapiocaOmnichainExtExec__factory } from '@typechain/index';

export const buildExtExec = async (
    hre: HardhatRuntimeEnvironment,
    deploymentName: string,
    args: Parameters<TapiocaOmnichainExtExec__factory['deploy']>,
    dependsOn: IDependentOn[],
): Promise<IDeployerVMAdd<TapiocaOmnichainExtExec__factory>> => {
    return {
        contract: await hre.ethers.getContractFactory(
            'TapiocaOmnichainExtExec',
        ),
        deploymentName,
        args,
        dependsOn,
    };
};
