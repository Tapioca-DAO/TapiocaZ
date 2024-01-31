import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const instantRedeemLocalOnBalancer__task = async (
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
    const { srcPoolId } = await inquirer.prompt({
        type: 'input',
        name: 'srcPoolId',
        message: 'Source LZ pool id',
        default: 0,
    });

    const { amountLP } = await inquirer.prompt({
        type: 'input',
        name: 'amountLP',
        message: 'LZ amount LP',
        default: 0,
    });

    const { to } = await inquirer.prompt({
        type: 'input',
        name: 'to',
        message: 'Receiver',
        default: hre.ethers.constants.AddressZero,
    });

    await (await balancer.instantRedeemLocal(srcPoolId, amountLP, to)).wait(3);
};
