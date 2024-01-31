import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const initConnectedOFT__task = async (
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

    const { srcOft } = await inquirer.prompt({
        type: 'input',
        name: 'srcOft',
        message: 'Source tOFT',
        default: hre.ethers.constants.AddressZero,
    });

    const { dstOft } = await inquirer.prompt({
        type: 'input',
        name: 'dstOft',
        message: 'Destination tOFT',
        default: hre.ethers.constants.AddressZero,
    });

    const { dstChainId } = await inquirer.prompt({
        type: 'input',
        name: 'dstChainId',
        message: 'Destination tOFT LZ chain id',
        default: 0,
    });

    const { ercData } = await inquirer.prompt({
        type: 'input',
        name: 'ercData',
        message: 'ERC20 data',
        default: '0x',
    });

    await (
        await balancer.initConnectedOFT(srcOft, dstChainId, dstOft, ercData)
    ).wait(3);
};
