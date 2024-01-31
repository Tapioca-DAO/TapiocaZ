import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const toggleSwapEth__task = async (
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
    const { status } = await inquirer.prompt({
        type: 'confirm',
        name: 'status',
        message: 'Enable?',
    });
    await (await balancer.setSwapEth(status)).wait(3);
};
