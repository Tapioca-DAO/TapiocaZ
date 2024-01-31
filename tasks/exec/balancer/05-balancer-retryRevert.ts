import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const retryRevertOnBalancer__task = async (
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
    const { srcChainId } = await inquirer.prompt({
        type: 'input',
        name: 'srcChainId',
        message: 'Source tOFT LZ chain id',
        default: 0,
    });

    const { srcAddress } = await inquirer.prompt({
        type: 'input',
        name: 'srcAddress',
        message: 'Source tOFT',
        default: hre.ethers.constants.AddressZero,
    });

    const { nonce } = await inquirer.prompt({
        type: 'input',
        name: 'nonce',
        message: 'Nonce',
        default: 0,
    });

    await (await balancer.retryRevert(srcChainId, srcAddress, nonce)).wait(3);
};
