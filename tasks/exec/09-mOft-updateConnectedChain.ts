import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const updateConnectedChain__task = async (
    {},
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
    const { chain } = await inquirer.prompt({
        type: 'input',
        name: 'chain',
        message: 'LZ chain id',
        default: hre.ethers.constants.AddressZero,
    });

    const { status } = await inquirer.prompt({
        type: 'confirm',
        name: 'status',
        message: 'Enable?',
    });

    const txData = dep.contract.interface.encodeFunctionData(
        'updateConnectedChain',
        [chain, status],
    );
    await (await wrapperDeployment.contract.executeTOFT(dep.contract.address, txData, true)).wait(3);
};
