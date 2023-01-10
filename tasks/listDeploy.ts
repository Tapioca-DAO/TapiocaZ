import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { TDeployment } from '../constants';
import { readTOFTDeployments } from '../scripts/utils';

export const getDeployments = async (
    {},
    hre: HardhatRuntimeEnvironment,
): Promise<TDeployment> => {
    const deployments = await hre.deployments.all();
    const formatted: any = {};
    for (const key of Object.keys(deployments)) {
        formatted[key] = deployments[key].address;
    }

    return {
        ...(readTOFTDeployments()[await hre.getChainId()] ?? {}),
        ...formatted,
    };
};

export const listDeploy__task = async ({}, hre: HardhatRuntimeEnvironment) => {
    console.log(await getDeployments({}, hre));
};
