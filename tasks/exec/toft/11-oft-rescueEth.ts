import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const rescueEthFromOft__task = async (
    args: { address: string; oft: boolean },
    hre: HardhatRuntimeEnvironment,
) => {
    const tOFT = args.oft
        ? await hre.ethers.getContractAt('TOFT', args.address)
        : await hre.ethers.getContractAt('mTOFT', args.address);

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

    await (await tOFT.rescueEth(amount, to)).wait(3);
};
