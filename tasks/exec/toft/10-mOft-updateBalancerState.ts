import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const updateBalancerState__task = async (
    args: { address: string },
    hre: HardhatRuntimeEnvironment,
) => {
    const { balancer } = await inquirer.prompt({
        type: 'input',
        name: 'balancer',
        message: 'Balancer address',
        default: hre.ethers.constants.AddressZero,
    });

    const { status } = await inquirer.prompt({
        type: 'confirm',
        name: 'status',
        message: 'Enable?',
    });

    const mTOFT = await hre.ethers.getContractAt('mTOFT', args.address);
    await (await mTOFT.updateBalancerState(balancer, status)).wait(3);
};
