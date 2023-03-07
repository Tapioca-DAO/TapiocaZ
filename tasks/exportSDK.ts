import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { API } from 'tapioca-sdk';
import { DEPLOYMENTS_FILE } from '../constants';

/**
 * Script used to generate typings for the tapioca-sdk
 * https://github.com/Tapioca-DAO/tapioca-sdk
 */
export const exportSDK__task = async ({}, hre: HardhatRuntimeEnvironment) => {
    await API.exportSDK.run({
        projectCaller: 'TapiocaZ',
        contractNames: ['TapiocaWrapper', 'TapiocaOFT'],
        artifactPath: hre.config.paths.artifacts,
        _deployments:
            Object.keys(DEPLOYMENTS_FILE).length > 0
                ? DEPLOYMENTS_FILE
                : undefined,
    });
};
