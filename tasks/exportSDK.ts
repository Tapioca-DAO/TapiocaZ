import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { API } from 'tapioca-sdk';
import { TLocalDeployment } from 'tapioca-sdk/dist/shared';
import { DEPLOYMENTS_FILE } from '../constants';

/**
 * Script used to generate typings for the tapioca-sdk
 * https://github.com/Tapioca-DAO/tapioca-sdk
 */
export const exportSDK__task = async (
    taskArgs: { tag?: string },
    hre: HardhatRuntimeEnvironment,
) => {
    const tag = taskArgs.tag || 'default';

    const data = hre.SDK.db.readDeployment('local', {
        tag,
    }) as TLocalDeployment;

    const contractNames = [
        'TapiocaWrapper',
        'mTapiocaOFT',
        'TapiocaOFT',
        'Rebalancer',
        'BaseTOFT',
    ];

    console.log(
        '[+] Exporting typechain & deployment files for tapioca-sdk...',
    );
    console.log(contractNames);

    hre.SDK.exportSDK.run({
        projectCaller: hre.config.SDK.project,
        artifactPath: hre.config.paths.artifacts,
        deployment: { data, tag },
        contractNames,
    });
};
