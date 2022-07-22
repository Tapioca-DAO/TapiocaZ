import fs from 'fs';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { glob, runTypeChain } from 'typechain';
import writeJsonFile from 'write-json-file';
import { LZ_ENDPOINTS } from '../scripts/constants';
/**
 * Script used to generate typings for the tapioca-sdk
 * https://github.com/Tapioca-DAO/tapioca-sdk
 */
export const exportSDK__task = async ({}, hre: HardhatRuntimeEnvironment) => {
    const cwd = process.cwd();

    const __deployments: any = { prev: {} };
    try {
        __deployments.prev = JSON.parse(
            fs.readFileSync('tapioca-sdk/src/addresses.json', 'utf-8'),
        );
    } catch (e) {}

    const deployments = {
        ...__deployments.prev,
        [await hre.getChainId()]: {
            ...__deployments.prev[await hre.getChainId()],
            tapiocaWrapper: (await hre.deployments.get('TapiocaWrapper'))
                .address,
        },
    };

    await writeJsonFile('tapioca-sdk/src/addresses.json', deployments);
    await writeJsonFile('tapioca-sdk/src/lz_endpoints.json', LZ_ENDPOINTS);

    const allFiles = glob(cwd, [
        `${hre.config.paths.artifacts}/**/!(*.dbg).json`,
    ]).filter((e) =>
        ['TapiocaWrapper', 'TapiocaOFT'].some(
            (v) => e.split('/').slice(-1)[0] === v.concat('.json'),
        ),
    );

    await runTypeChain({
        cwd,
        filesToProcess: allFiles,
        allFiles,
        outDir: 'tapioca-sdk/src/typechain/TapiocaZ',
        target: 'ethers-v5',
        flags: {
            alwaysGenerateOverloads: true,
            environment: 'hardhat',
        },
    });
};
