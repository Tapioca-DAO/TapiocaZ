import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { TLocalDeployment } from 'tapioca-sdk/dist/shared';
import inquirer from 'inquirer';

/**
 * Script used to generate typings for the tapioca-sdk
 * https://github.com/Tapioca-DAO/tapioca-sdk
 */
export const exportSDK__task = async ({}, hre: HardhatRuntimeEnvironment) => {
    console.log(
        '\n\n[+] Exporting typechain & deployment files for tapioca-sdk...',
    );
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const data = hre.SDK.db.readDeployment('local', {
        tag,
    }) as TLocalDeployment;

    if (!tag) {
        console.log('[-] No local deployment found. Skipping to typechain');
    }

    const allContracts = (await hre.artifacts.getAllFullyQualifiedNames())
        .filter((e) => e.startsWith('contracts/'))
        .map((e) => e.split(':')[1])
        .filter((e) => e[0] !== 'I');

    const { contractNames } = await inquirer.prompt({
        type: 'checkbox',
        message: 'Select contracts to export',
        name: 'contractNames',
        choices: allContracts,
        default: allContracts,
    });

    console.log(
        '[+] Exporting typechain & deployment files for tapioca-sdk...',
    );

    hre.SDK.exportSDK.run({
        projectCaller: hre.config.SDK.project,
        artifactPath: hre.config.paths.artifacts,
        deployment: { data, tag },
        contractNames,
    });
};
