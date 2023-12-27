import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const rescueEthFromOft__task = async (
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
    const { to } = await inquirer.prompt({
        type: 'input',
        name: 'to',
        message: 'Receiver address',
        default: hre.ethers.constants.AddressZero,
    });
    const { amount } = await inquirer.prompt({
        type: 'input',
        name: 'amount',
        message: 'Receiver address',
        default: hre.ethers.constants.AddressZero,
    });

    const txData = dep.contract.interface.encodeFunctionData(
        'rescueEth',
        [amount, to],
    );
    await (await wrapperDeployment.contract.executeTOFT(dep.contract.address, txData, true)).wait(3);
};
