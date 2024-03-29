import { HardhatRuntimeEnvironment } from 'hardhat/types';
import {
    TTapiocaDeployTaskArgs,
    TTapiocaDeployerVmPass,
} from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { buildMTOFT } from 'tasks/deployBuilds/buildMTOFT';
import { buildToftVault } from 'tasks/deployBuilds/buildToftVault';
import { DEPLOYMENT_NAMES, DEPLOY_CONFIG } from './DEPLOY_CONFIG';
import {
    VMAddToftModule,
    areModulesDeployed,
    getInitStruct,
    getModuleStruct,
} from './toftDeployerUtils';
import { buildTOFT } from 'tasks/deployBuilds/buildTOFT';

export type TToftDeployerTaskArgs = TTapiocaDeployTaskArgs & {
    erc20: string;
    target: 'toft' | 'mtoft';
    deploymentName: string;
    name: string;
    symbol: string;
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
    const { tag, deploymentName, erc20, name, symbol, target } = taskArgs;
    const owner = tapiocaMulticallAddr;

    // Add TOFT modules
    if (!areModulesDeployed({ hre, tag })) {
        await VMAddToftModule({ hre, VM, owner });
    } else {
        console.log('[+] Reusing TOFT modules');
        VM.load(
            hre.SDK.db.loadLocalDeployment(tag, hre.SDK.eChainId)?.contracts ??
                [],
        );
    }

    const vaultDeploymentName = `${DEPLOYMENT_NAMES.TOFT_VAULT}/${deploymentName}`;
    const [initStruct, dependsOnInitStruct] = await getInitStruct({
        hre,
        tag,
        owner,
        erc20,
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
