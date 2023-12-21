import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const updateConnectedChain__task = async (
    taskArgs: {},
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

    await (await oft.updateConnectedChain(chain, status)).wait(3);
};
