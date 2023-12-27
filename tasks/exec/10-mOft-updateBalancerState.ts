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

    const wrapperDeployment = await hre.SDK.hardhatUtils.getLocalContract(
        hre,
        'TapiocaWrapper',
        tag,
    );

    if (!wrapperDeployment) {
        throw new Error('[-] TapiocaWrapper not found');
    }
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

    const txData = dep.contract.interface.encodeFunctionData(
        'updateBalancerState',
        [balancer, status],
    );
    await (await wrapperDeployment.contract.executeTOFT(dep.contract.address, txData, true)).wait(3);
};
