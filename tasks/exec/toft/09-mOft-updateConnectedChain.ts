import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const updateConnectedChain__task = async (
    args: { address: string },
    hre: HardhatRuntimeEnvironment,
) => {
    const mTOFT = await hre.ethers.getContractAt('mTOFT', args.address);

    const { chain } = await inquirer.prompt({
        type: 'input',
        name: 'chain',
        message: 'LZ chain id',
        default: hre.ethers.constants.AddressZero,
    });

    await (await mTOFT.setConnectedChain(chain)).wait(3);
};
