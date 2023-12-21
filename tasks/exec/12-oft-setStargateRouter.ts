import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import inquirer from 'inquirer';

export const setStargateRouterOnOft__task = async (
    taskArgs: { oft: string },
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

    const { router } = await inquirer.prompt({
        type: 'input',
        name: 'router',
        message: 'Stargate router address',
        default: hre.ethers.constants.AddressZero,
    });

    await (await oft.setStargateRouter(router)).wait(3);
};
