import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const setStargateRouterOnOft__task = async (
    args: { address: string },
    hre: HardhatRuntimeEnvironment,
) => {
    const tOFT = await hre.ethers.getContractAt('mTOFT', args.address);

    const { router } = await inquirer.prompt({
        type: 'input',
        name: 'router',
        message: 'Stargate router address',
        default: hre.ethers.constants.AddressZero,
    });
    await (await tOFT.setStargateRouter(router)).wait(3);
};
