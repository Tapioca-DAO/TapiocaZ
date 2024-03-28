import * as PERIPH_DEPLOY_CONFIG from '@tapioca-periph/config';

import { TOFTInitStructStruct } from '@typechain/contracts/tOFT/TOFT';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import {
    DeployerVM,
    TTapiocaDeployTaskArgs,
    TTapiocaDeployerVmPass,
} from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { buildExtExec } from 'tasks/deployBuilds/buildExtExec';
import { buildTOFTGenericReceiverModule } from 'tasks/deployBuilds/buildTOFTGenericReceiverModule';
import { buildTOFTMarketReceiverModule } from 'tasks/deployBuilds/buildTOFTMarketReceiverModule';
import { buildTOFTOptionsReceiverModule } from 'tasks/deployBuilds/buildTOFTOptionsReceiverModule';
import { buildTOFTReceiverModule } from 'tasks/deployBuilds/buildTOFTReceiverModule';
import { buildTOFTSenderModule } from 'tasks/deployBuilds/buildTOFTSenderModule';
import { DEPLOYMENT_NAMES } from './DEPLOY_CONFIG';
import { loadGlobalContract } from 'tapioca-sdk';
import { TAPIOCA_PROJECTS_NAME } from 'tapioca-sdk/dist/api/config';
import { deployMTWETHMainnet__task } from './ethereum/deployMTWETHMainnet__task';

export const deployPostLbp__task = async (
    _taskArgs: TTapiocaDeployTaskArgs,
    hre: HardhatRuntimeEnvironment,
) => {
    await hre.SDK.DeployerVM.tapiocaDeployTask(
        _taskArgs,
        { hre },
        tapiocaDeployTask,
    );
};

async function tapiocaDeployTask(params: TTapiocaDeployerVmPass<object>) {
    const { hre, VM, tapiocaMulticallAddr, taskArgs, isTestnet } = params;
    const { tag } = taskArgs;
    const owner = tapiocaMulticallAddr;

    await deployMTWETHMainnet__task(taskArgs, hre);
}

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
