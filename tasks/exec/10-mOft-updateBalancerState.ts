import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const updateBalancerState__task = async (
    taskArgs: { oft: string },
    hre: HardhatRuntimeEnvironment,
) => {
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const dep = await hre.SDK.hardhatUtils.getLocalContract(
        hre,
        'mTapiocaOFT',
        tag,
    );
    const oft = await hre.ethers.getContractAt(
        'mTapiocaOFT',
        dep.contract.address,
    );

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

    await (await oft.updateBalancerState(balancer, status)).wait(3);
};
