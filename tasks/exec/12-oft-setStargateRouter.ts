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

    const { router } = await inquirer.prompt({
        type: 'input',
        name: 'router',
        message: 'Stargate router address',
        default: hre.ethers.constants.AddressZero,
    });

    const txData = dep.contract.interface.encodeFunctionData(
        'setStargateRouter',
        [router],
    );
    await (
        await wrapperDeployment.contract.executeTOFT(
            dep.contract.address,
            txData,
            true,
        )
    ).wait(3);
};
