import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { registerVesting, updateDeployments } from '../deploy/utils';

export const deployVesting__task = async (taskArgs: any, hre: HardhatRuntimeEnvironment) => {
    const vestingObj = await registerVesting(hre, taskArgs.token, taskArgs.cliff, taskArgs.duration);
    await updateDeployments([vestingObj], await hre.getChainId());
};
