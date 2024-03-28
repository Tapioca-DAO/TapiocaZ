import SUPPORTED_CHAINS from '@tapioca-sdk/SUPPORTED_CHAINS';
import { getChainBy } from '@tapioca-sdk/api/utils';
import { IDependentOn } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { TOFTInitStructStruct } from '@typechain/contracts/tOFT/MTOFT';
import { TOFTModulesInitStructStruct } from '@typechain/contracts/tOFT/TOFT';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import {
    TTapiocaDeployTaskArgs,
    TTapiocaDeployerVmPass,
} from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { buildMTOFT } from 'tasks/deployBuilds/buildMTOFT';
import { buildToftVault } from 'tasks/deployBuilds/buildToftVault';
import {
    VMAddToftModule,
    getExternalContracts,
} from '../1-deployPostLbp__task';
import { DEPLOYMENT_NAMES, DEPLOY_CONFIG } from '../DEPLOY_CONFIG';

export const deployMTWETHMainnet__task = async (
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
    const { hre, VM, tapiocaMulticallAddr, taskArgs, isTestnet, chainInfo } =
        params;
    const { tag } = taskArgs;
    const owner = tapiocaMulticallAddr;

    // Add TOFT modules
    const vaultName = `${DEPLOYMENT_NAMES.TOFT_VAULT}/${DEPLOYMENT_NAMES.MTOFT_WETH}`;
    await VMAddToftModule({ hre, VM, owner });

    const [initStruct, dependsOnInitStruct] = await getInitStruct({
        hre,
        tag,
        owner,
        vaultName,
        isTestnet,
        chainInfo,
    });
    const [moduleStruct, dependsOnModuleStruct] = getModuleStruct({ hre });

    VM.add(
        await buildToftVault(hre, vaultName, [
            DEPLOY_CONFIG.POST_LBP[chainInfo.chainId]!.WETH,
        ]),
    ).add(
        await buildMTOFT(
            hre,
            DEPLOYMENT_NAMES.MTOFT_WETH,
            [
                initStruct,
                moduleStruct,
                DEPLOY_CONFIG.MISC[chainInfo.chainId]!.STARGATE_ROUTER,
            ],
            [...dependsOnInitStruct, ...dependsOnModuleStruct],
        ),
    );
}

async function getInitStruct(params: {
    hre: HardhatRuntimeEnvironment;
    tag: string;
    owner: string;
    vaultName: string;
    isTestnet: boolean;
    chainInfo: (typeof SUPPORTED_CHAINS)[number];
}): Promise<[TOFTInitStructStruct, IDependentOn[]]> {
    const { hre, tag, owner, isTestnet, chainInfo, vaultName } = params;

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
            endpoint: hre.SDK.chainInfo.address,
            erc20: DEPLOY_CONFIG.POST_LBP[chainInfo.chainId]!.WETH,
            extExec: addrZero,
            hostEid: arbitrumEid,
            name: DEPLOYMENT_NAMES.MTOFT_WETH,
            pearlmit: pearlmit.address,
            symbol: DEPLOYMENT_NAMES.MTOFT_WETH,
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
                deploymentName: vaultName,
            },
        ],
    ];
}

function getModuleStruct(params: {
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
