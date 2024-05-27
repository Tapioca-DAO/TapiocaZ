import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { TTapiocaDeployerVmPass } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { buildBalancer } from 'tasks/deployBuilds/buildBalancer';
import { DEPLOYMENT_NAMES, DEPLOY_CONFIG } from './DEPLOY_CONFIG';
import { TToftDeployerTaskArgs, VMAddToft } from './toftDeployer__task';

/**
 * @notice Should be called after the LBP has ended. Before `Bar` `postLbp1`
 * @notice Will deploy mtETH, tWSTETH, and tRETH. Will also set the LzPeer for mtETH (disabled for prod).
 * @notice Will deploy Balancer contract.
 */
export const deployPostLbp__task = async (
    _taskArgs: TToftDeployerTaskArgs,
    hre: HardhatRuntimeEnvironment,
) => {
    await hre.SDK.DeployerVM.tapiocaDeployTask(
        _taskArgs,
        {
            hre,
            // Static simulation needs to be false, constructor relies on external call. We're using 0x00 replacement with DeployerVM, which creates a false positive for static simulation.
            staticSimulation: false,
        },
        tapiocaDeployTask,
        tapiocaPostDeployTask,
    );
};

async function tapiocaPostDeployTask(params: TTapiocaDeployerVmPass<object>) {
    const { hre, taskArgs, VM, chainInfo } = params;
    const { tag } = taskArgs;

    if (
        chainInfo.name === 'ethereum' ||
        chainInfo.name === 'arbitrum' ||
        chainInfo.name === 'optimism' ||
        chainInfo.name === 'sepolia' ||
        chainInfo.name === 'arbitrum_sepolia' ||
        chainInfo.name === 'optimism_sepolia'
    ) {
        console.log(
            '\n[+] Disabled setting Balancer connected OFT for mtETH...',
        );
        // await setLzPeer__task({ tag, targetName: DEPLOYMENT_NAMES.mtETH }, hre);

        // await balancerInnitConnectedOft__task(
        //     { ...taskArgs, targetName: DEPLOYMENT_NAMES.mtETH },
        //     hre,
        // );
    }
}

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

    const hostChainInfo = hre.SDK.utils.getChainBy(
        'name',
        isTestnet ? 'arbitrum_sepolia' : 'arbitrum',
    );

    // VM Add mtETH
    if (
        chainInfo.name === 'arbitrum' ||
        chainInfo.name === 'ethereum' ||
        chainInfo.name === 'optimism' ||
        // testnet
        chainInfo.name === 'sepolia' ||
        chainInfo.name === 'arbitrum_sepolia' ||
        chainInfo.name === 'optimism_sepolia'
    ) {
        console.log('\n[+] Adding mtOFT contracts');
        await VMAddToftWithArgs({
            ...taskArgs,
            target: 'mtoft',
            deploymentName: DEPLOYMENT_NAMES.mtETH,
            erc20: DEPLOY_CONFIG.POST_LBP[chainInfo.chainId]!.WETH,
            name: 'MTOFT Wrapped Ether',
            symbol: DEPLOYMENT_NAMES.mtETH,
            hostEid: hostChainInfo.lzChainId,
        });

        VM.add(
            await buildBalancer(hre, DEPLOYMENT_NAMES.TOFT_BALANCER, [
                DEPLOY_CONFIG.MISC[chainInfo.chainId]!.STARGATE_ROUTER_ETH,
                DEPLOY_CONFIG.MISC[chainInfo.chainId]!.STARGATE_ROUTER,
                DEPLOY_CONFIG.MISC[chainInfo.chainId]!.STARGATE_ROUTER,
                owner,
            ]),
        );
    }

    // VM Add BB + SGL OFTs
    if (
        chainInfo.name === 'arbitrum' ||
        // testnet
        chainInfo.name === 'arbitrum_sepolia'
    ) {
        console.log('\n[+] Adding tOFT contracts');
        // VM Add tWSTETH
        await VMAddToftWithArgs({
            ...taskArgs,
            target: 'toft',
            deploymentName: DEPLOYMENT_NAMES.tWSTETH,
            erc20: DEPLOY_CONFIG.POST_LBP[chainInfo.chainId]!.wstETH,
            name: 'Tapioca OFT Lido Wrapped Staked Ether',
            symbol: DEPLOYMENT_NAMES.tWSTETH,
            noModuleDeploy: true, // Modules are loaded here
            hostEid: hostChainInfo.lzChainId,
        });

        // VM Add tRETH
        await VMAddToftWithArgs({
            ...taskArgs,
            target: 'toft',
            deploymentName: DEPLOYMENT_NAMES.tRETH,
            erc20: DEPLOY_CONFIG.POST_LBP[chainInfo.chainId]!.reth,
            name: 'Tapioca OFT Rocket Pool Ether',
            symbol: DEPLOYMENT_NAMES.tRETH,
            noModuleDeploy: true,
            hostEid: hostChainInfo.lzChainId,
        });

        // VM Add sGLP
        await VMAddToftWithArgs({
            ...taskArgs,
            target: 'toft',
            deploymentName: DEPLOYMENT_NAMES.tsGLP,
            erc20: DEPLOY_CONFIG.POST_LBP[chainInfo.chainId]!.sGLP,
            name: 'Tapioca OFT Staked GLP',
            symbol: DEPLOYMENT_NAMES.tsGLP,
            noModuleDeploy: true,
            hostEid: hostChainInfo.lzChainId,
        });
    }

    if (
        chainInfo.name === 'ethereum' ||
        // testnet
        chainInfo.name === 'sepolia' ||
        chainInfo.name === 'optimism_sepolia'
    ) {
        console.log('\n[+] Adding tOFT contracts');
        const sideChainHostChainInfo = hre.SDK.utils.getChainBy(
            'name',
            isTestnet ? 'optimism_sepolia' : 'ethereum',
        );
        // VM Add sDAI
        await VMAddToftWithArgs({
            ...taskArgs,
            target: 'toft',
            deploymentName: DEPLOYMENT_NAMES.tsDAI,
            erc20: DEPLOY_CONFIG.POST_LBP[chainInfo.chainId]!.sDAI,
            name: 'Tapioca OFT Staked DAI',
            symbol: DEPLOYMENT_NAMES.tsDAI,
            noModuleDeploy: true,
            hostEid: sideChainHostChainInfo.lzChainId,
        });
    }
}
