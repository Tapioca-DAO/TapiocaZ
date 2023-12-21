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
        'TapiocaOFT',
        tag,
    );
    const oft = await hre.ethers.getContractAt(
        'TapiocaOFT',
        dep.contract.address,
    );

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

    await (await oft.rescueEth(amount, to)).wait(3);
};
