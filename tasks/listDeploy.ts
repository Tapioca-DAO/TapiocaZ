import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { readTOFTDeployments } from '../scripts/utils';

export const listDeploy = async ({}, hre: HardhatRuntimeEnvironment) => {
    const deployments = await hre.deployments.all();
    const formatted: any = {};
    for (const key of Object.keys(deployments)) {
        formatted[key] = deployments[key].address;
    }

    console.log({
        ...(readTOFTDeployments()[await hre.getChainId()] ?? {}),
        ...formatted,
    });
};
