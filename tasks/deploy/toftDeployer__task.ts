import { HardhatRuntimeEnvironment } from 'hardhat/types';
import {
    TTapiocaDeployTaskArgs,
    TTapiocaDeployerVmPass,
} from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { buildMTOFT } from 'tasks/deployBuilds/buildMTOFT';
import { buildTOFT } from 'tasks/deployBuilds/buildTOFT';
import { buildToftVault } from 'tasks/deployBuilds/buildToftVault';
import { DEPLOYMENT_NAMES, DEPLOY_CONFIG } from './DEPLOY_CONFIG';
import {
    VMAddToftModule,
    getInitStruct,
    getModuleStruct,
} from './toftDeployerUtils';

export type TToftDeployerTaskArgs = TTapiocaDeployTaskArgs & {
    erc20: string;
    target: 'toft' | 'mtoft';
    hostEid: string | number;
    deploymentName: string;
    name: string;
    symbol: string;
    noModuleDeploy?: boolean;
};
export const toftDeployer__task = async (
    _taskArgs: TToftDeployerTaskArgs,
    hre: HardhatRuntimeEnvironment,
) => {
    await hre.SDK.DeployerVM.tapiocaDeployTask(_taskArgs, { hre }, VMAddToft);
};

export async function VMAddToft(
    params: TTapiocaDeployerVmPass<TToftDeployerTaskArgs>,
) {
    const { hre, VM, tapiocaMulticallAddr, taskArgs, isTestnet, chainInfo } =
        params;
    const { tag, deploymentName, erc20, name, symbol, target, noModuleDeploy } =
        taskArgs;
    const owner = tapiocaMulticallAddr;

    if (!noModuleDeploy) {
        await VMAddToftModule({ hre, VM, owner, tag });
    }

    const vaultDeploymentName = `${DEPLOYMENT_NAMES.TOFT_VAULT}/${deploymentName}`;
    const [initStruct, dependsOnInitStruct] = await getInitStruct({
        hre,
        tag,
        owner,
        erc20,
        hostEid,
        name,
        symbol,
        vaultDeploymentName,
        isTestnet,
        chainInfo,
    });
    const [moduleStruct, dependsOnModuleStruct] = getModuleStruct({ hre });

    VM.add(await buildToftVault(hre, vaultDeploymentName, [erc20]));

    if (target === 'toft') {
        VM.add(
            await buildTOFT(
                hre,
                deploymentName,
                [initStruct, moduleStruct],
                [...dependsOnInitStruct, ...dependsOnModuleStruct],
            ),
        );
    } else if (target === 'mtoft') {
        const toft = await hre.ethers.getContractFactory('TOFT');
        VM.add(
            await buildMTOFT(
                hre,
                deploymentName,
                [
                    initStruct,
                    moduleStruct,
                    DEPLOY_CONFIG.MISC[chainInfo.chainId]!.STARGATE_ROUTER,
                ],
                [...dependsOnInitStruct, ...dependsOnModuleStruct],
            ),
        );
    } else {
        throw new Error('[-] Invalid target. Use "toft" or "mtoft"');
    }
}
