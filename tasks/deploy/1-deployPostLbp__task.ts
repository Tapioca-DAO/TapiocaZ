import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { TTapiocaDeployerVmPass } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { DEPLOYMENT_NAMES, DEPLOY_CONFIG } from './DEPLOY_CONFIG';
import { TToftDeployerTaskArgs, VMAddToft } from './toftDeployer__task';

export const deployPostLbp__task = async (
    _taskArgs: TToftDeployerTaskArgs,
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

    const VMAddToftWithArgs = async (args: TToftDeployerTaskArgs) =>
        await VMAddToft({
            chainInfo,
            hre,
            isTestnet,
            tapiocaMulticallAddr,
            VM,
            taskArgs: args,
        });

    // VM Add mtWETH
    await VMAddToftWithArgs({
        ...taskArgs,
        deploymentName: DEPLOYMENT_NAMES.mtWETH,
        erc20: DEPLOY_CONFIG.POST_LBP[chainInfo.chainId]!.WETH,
        name: 'MTOFT Wrapped Ether',
        symbol: DEPLOYMENT_NAMES.mtWETH,
        target: 'mtoft',
        tag,
    });

    // VM Add tWSTETH
    await VMAddToftWithArgs({
        ...taskArgs,
        deploymentName: DEPLOYMENT_NAMES.tWSTETH,
        erc20: DEPLOY_CONFIG.POST_LBP[chainInfo.chainId]!.wstETH,
        name: 'TOFT Wrapped Staked Ether',
        symbol: DEPLOYMENT_NAMES.tWSTETH,
        target: 'toft',
        tag,
    });

    // VM Add tRETH
    await VMAddToftWithArgs({
        ...taskArgs,
        deploymentName: DEPLOYMENT_NAMES.tRETH,
        erc20: DEPLOY_CONFIG.POST_LBP[chainInfo.chainId]!.wstETH,
        name: 'TOFT Rocket Ether',
        symbol: DEPLOYMENT_NAMES.tRETH,
        target: 'toft',
        tag,
    });
}
