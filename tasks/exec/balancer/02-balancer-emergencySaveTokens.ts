import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const emergencySaveTokens__task = async (
    {},
    hre: HardhatRuntimeEnvironment,
) => {
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const dep = await hre.SDK.hardhatUtils.getLocalContract(
        hre,
        'Balancer',
        tag,
    );
    const balancer = await hre.ethers.getContractAt(
        'Balancer',
        dep.contract.address,
    );
    const { token } = await inquirer.prompt({
        type: 'input',
        name: 'token',
        message: 'Token address',
        default: hre.ethers.constants.AddressZero,
    });

    const { amount } = await inquirer.prompt({
        type: 'input',
        name: 'amount',
        message: 'Token amount',
        default: hre.ethers.constants.AddressZero,
    });

    await (await balancer.emergencySaveTokens(token, amount)).wait(3);
};
