import * as PERIPH_DEPLOY_CONFIG from '@tapioca-periph/config';

import SUPPORTED_CHAINS from '@tapioca-sdk/SUPPORTED_CHAINS';
import { getChainBy } from '@tapioca-sdk/api/utils';
import { IDependentOn } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import {
    TOFTInitStructStruct,
    TOFTModulesInitStructStruct,
} from '@typechain/contracts/tOFT/TOFT';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { loadGlobalContract, loadLocalContract } from 'tapioca-sdk';
import { TAPIOCA_PROJECTS_NAME } from 'tapioca-sdk/dist/api/config';
import { DeployerVM } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { buildExtExec } from 'tasks/deployBuilds/buildExtExec';
import { buildTOFTGenericReceiverModule } from 'tasks/deployBuilds/buildTOFTGenericReceiverModule';
import { buildTOFTMarketReceiverModule } from 'tasks/deployBuilds/buildTOFTMarketReceiverModule';
import { buildTOFTOptionsReceiverModule } from 'tasks/deployBuilds/buildTOFTOptionsReceiverModule';
import { buildTOFTReceiverModule } from 'tasks/deployBuilds/buildTOFTReceiverModule';
import { buildTOFTSenderModule } from 'tasks/deployBuilds/buildTOFTSenderModule';
import { DEPLOYMENT_NAMES } from './DEPLOY_CONFIG';

export async function VMAddToftModule(params: {
    hre: HardhatRuntimeEnvironment;
    VM: DeployerVM;
    owner: string;
}) {
    const { hre, VM, owner } = params;
    const addrZero = hre.ethers.constants.AddressZero;
    const initStruct: TOFTInitStructStruct = {
        cluster: addrZero,
        delegate: addrZero,
        endpoint: addrZero,
        erc20: addrZero,
        extExec: addrZero,
        hostEid: 0,
        name: 'TOFT Module',
        pearlmit: addrZero,
        symbol: 'TOFT Module',
        vault: addrZero,
        yieldBox: addrZero,
    };

    VM.add(
        await buildExtExec(
            hre,
            DEPLOYMENT_NAMES.TOFT_EXT_EXEC,
            [
                addrZero, // Cluster
                owner, // Owner
            ],
            [
                {
                    argPosition: 0,
                    deploymentName:
                        PERIPH_DEPLOY_CONFIG.DEPLOYMENT_NAMES.CLUSTER,
                },
            ],
        ),
    )
        .add(
            await buildTOFTGenericReceiverModule(
                hre,
                DEPLOYMENT_NAMES.TOFT_GENERIC_RECEIVER_MODULE,
                [initStruct],
            ),
        )
        .add(
            await buildTOFTMarketReceiverModule(
                hre,
                DEPLOYMENT_NAMES.TOFT_MARKET_RECEIVER_MODULE,
                [initStruct],
            ),
        )
        .add(
            await buildTOFTOptionsReceiverModule(
                hre,
                DEPLOYMENT_NAMES.TOFT_OPTIONS_RECEIVER_MODULE,
                [initStruct],
            ),
        )
        .add(
            await buildTOFTReceiverModule(
                hre,
                DEPLOYMENT_NAMES.TOFT_RECEIVER_MODULE,
                [initStruct],
            ),
        )
        .add(
            await buildTOFTSenderModule(
                hre,
                DEPLOYMENT_NAMES.TOFT_SENDER_MODULE,
                [initStruct],
            ),
        );
}

export async function getExternalContracts(params: {
    hre: HardhatRuntimeEnvironment;
    tag: string;
}) {
    const { hre, tag } = params;

    const yieldBox = loadGlobalContract(
        hre,
        TAPIOCA_PROJECTS_NAME.YieldBox,
        hre.SDK.chainInfo.chainId,
        PERIPH_DEPLOY_CONFIG.DEPLOYMENT_NAMES.YieldBox,
        tag,
    );
    const cluster = loadGlobalContract(
        hre,
        TAPIOCA_PROJECTS_NAME.TapiocaPeriph,
        hre.SDK.chainInfo.chainId,
        PERIPH_DEPLOY_CONFIG.DEPLOYMENT_NAMES.CLUSTER,
        tag,
    );
    const pearlmit = loadGlobalContract(
        hre,
        TAPIOCA_PROJECTS_NAME.TapiocaPeriph,
        hre.SDK.chainInfo.chainId,
        PERIPH_DEPLOY_CONFIG.DEPLOYMENT_NAMES.PEARLMIT,
        tag,
    );

    return { yieldBox, cluster, pearlmit };
}

export function areModulesDeployed(params: {
    hre: HardhatRuntimeEnvironment;
    tag: string;
}) {
    const { hre, tag } = params;
    try {
        loadLocalContract(
            hre,
            hre.SDK.chainInfo.chainId,
            DEPLOYMENT_NAMES.TOFT_EXT_EXEC,
            tag,
        );
        return true;
    } catch (e) {
        return false;
    }
}

export async function getInitStruct(params: {
    hre: HardhatRuntimeEnvironment;
    tag: string;
    owner: string;
    erc20: string;
    name: string;
    symbol: string;
    vaultDeploymentName: string;
    isTestnet: boolean;
    chainInfo: (typeof SUPPORTED_CHAINS)[number];
}): Promise<[TOFTInitStructStruct, IDependentOn[]]> {
    const {
        hre,
        tag,
        owner,
        isTestnet,
        chainInfo,
        vaultDeploymentName,
        erc20,
        name,
        symbol,
    } = params;

    const addrZero = hre.ethers.constants.AddressZero;
    const arbitrumEid = isTestnet
        ? getChainBy('name', 'arbitrum').lzChainId
        : getChainBy('name', 'arbitrum_sepolia').lzChainId;

    const { cluster, pearlmit, yieldBox } = await getExternalContracts({
        hre,
        tag,
    });
    return [
        {
            cluster: cluster.address,
            delegate: owner,
            endpoint: chainInfo.address,
            erc20,
            extExec: addrZero,
            hostEid: arbitrumEid,
            name,
            pearlmit: pearlmit.address,
            symbol,
            vault: addrZero,
            yieldBox: yieldBox.address,
        },
        [
            {
                argPosition: 0,
                keyName: 'extExec',
                deploymentName: DEPLOYMENT_NAMES.TOFT_EXT_EXEC,
            },
            {
                argPosition: 0,
                keyName: 'vault',
                deploymentName: vaultDeploymentName,
            },
        ],
    ];
}

export function getModuleStruct(params: {
    hre: HardhatRuntimeEnvironment;
}): [TOFTModulesInitStructStruct, IDependentOn[]] {
    const { hre } = params;
    const addrZero = hre.ethers.constants.AddressZero;

    return [
        {
            genericReceiverModule: addrZero,
            marketReceiverModule: addrZero,
            optionsReceiverModule: addrZero,
            tOFTReceiverModule: addrZero,
            tOFTSenderModule: addrZero,
        },
        [
            {
                argPosition: 0,
                keyName: 'genericReceiverModule',
                deploymentName: DEPLOYMENT_NAMES.TOFT_GENERIC_RECEIVER_MODULE,
            },
            {
                argPosition: 0,
                keyName: 'marketReceiverModule',
                deploymentName: DEPLOYMENT_NAMES.TOFT_MARKET_RECEIVER_MODULE,
            },
            {
                argPosition: 0,
                keyName: 'optionsReceiverModule',
                deploymentName: DEPLOYMENT_NAMES.TOFT_OPTIONS_RECEIVER_MODULE,
            },
            {
                argPosition: 0,
                keyName: 'tOFTReceiverModule',
                deploymentName: DEPLOYMENT_NAMES.TOFT_RECEIVER_MODULE,
            },
            {
                argPosition: 0,
                keyName: 'tOFTSenderModule',
                deploymentName: DEPLOYMENT_NAMES.TOFT_SENDER_MODULE,
            },
        ],
    ];
}
