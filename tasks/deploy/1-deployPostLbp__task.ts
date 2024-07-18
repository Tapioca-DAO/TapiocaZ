import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { TTapiocaDeployerVmPass } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { buildBalancer } from 'tasks/deployBuilds/buildBalancer';
import { DEPLOYMENT_NAMES, DEPLOY_CONFIG } from './DEPLOY_CONFIG';
import { TToftDeployerTaskArgs, VMAddToft } from './toftDeployer__task';
import { buildToftHelper } from 'tasks/deployBuilds/buildToftHelper';
import { setLzPeer__task } from 'tapioca-sdk';

/**
 * @notice Should be called after the LBP has ended. Before `Bar` `postLbp1`
 *
 * Deploys: Arb, ETh
 * - mtETH
 * - tWSTETH
 * - tRETH
 * - tsDAI
 *
 * Post deploy: Arb
 *  !!! REQUIRE HAVING 1 amount of sDAI, mtEth, Reth, WSTETH, SGLP, Weth in TapiocaMulticall !!!
 * - Set LzPeer for mtETH (disabled for prod)
 * - Balancer contract (disabled for prod)
 */
export const deployPostLbp__task = async (
    _taskArgs: TToftDeployerTaskArgs & { sdaiHostChainName: string },
    hre: HardhatRuntimeEnvironment,
) => {
    await hre.SDK.DeployerVM.tapiocaDeployTask(
        _taskArgs,
        {
            hre,
            // Static simulation needs to be false, constructor relies on external call. We're using 0x00 replacement with DeployerVM, which creates a false positive for static simulation.
            staticSimulation: false,
            // bytecodeSizeLimit: 70_000,
            // overrideOptions: {
            //     gasLimit: 10_000_000,
            // },
        },
        tapiocaDeployTask,
        tapiocaPostDeployTask,
    );
};

async function tapiocaPostDeployTask(
    params: TTapiocaDeployerVmPass<{ sdaiHostChainName: string }>,
) {
    const { hre, taskArgs, VM, chainInfo } = params;
    const { tag } = taskArgs;

    console.log('\n[+] Disabled setting Balancer connected OFT for mtETH...');
    await setLzPeer__task({ tag, targetName: DEPLOYMENT_NAMES.mtETH }, hre);

    // await balancerInnitConnectedOft__task(
    //     { ...taskArgs, targetName: DEPLOYMENT_NAMES.mtETH },
    //     hre,
    // );
}

async function tapiocaDeployTask(
    params: TTapiocaDeployerVmPass<{ sdaiHostChainName: string }>,
) {
    const {
        hre,
        VM,
        tapiocaMulticallAddr,
        taskArgs,
        isTestnet,
        chainInfo,
        isHostChain,
        isSideChain,
    } = params;
    const { tag } = taskArgs;
    const owner = tapiocaMulticallAddr;

    const sdaiSideChain = hre.SDK.utils.getChainBy(
        'name',
        taskArgs.sdaiHostChainName,
    );
    if (!sdaiSideChain) {
        throw new Error(
            `[-] Can not find side info with chain name: ${taskArgs.sdaiHostChainName}`,
        );
    }

    VM.add(await buildToftHelper(hre, DEPLOYMENT_NAMES.TOFT_HELPER));

    const VMAddToftWithArgs = async (args: TToftDeployerTaskArgs) =>
        await VMAddToft({
            chainInfo,
            hre,
            isTestnet,
            tapiocaMulticallAddr,
            isHostChain,
            isSideChain,
            VM,
            taskArgs: args,
        });

    const hostChainInfo = hre.SDK.utils.getChainBy(
        'name',
        isTestnet ? 'arbitrum_sepolia' : 'arbitrum',
    );
    if (isTestnet) {
        await VMAddToftWithArgs({
            ...taskArgs,
            target: 'toft',
            deploymentName: DEPLOYMENT_NAMES.tUsdcMock,
            erc20: DEPLOY_CONFIG.POST_LBP[chainInfo.chainId]!.usdcMock,
            name: 'Tapioca OFT USDC Mock',
            symbol: DEPLOYMENT_NAMES.tUsdcMock,
            noModuleDeploy: false,
            hostEid: hostChainInfo.lzChainId,
        });
    }

    // VM Add mtETH
    console.log('\n[+] Adding mtOFT contracts');
    await VMAddToftWithArgs({
        ...taskArgs,
        target: 'mtoft',
        deploymentName: DEPLOYMENT_NAMES.mtETH,
        erc20: DEPLOY_CONFIG.POST_LBP[chainInfo.chainId]!.WETH,
        name: 'Multi Tapioca OFT Native Ether',
        symbol: DEPLOYMENT_NAMES.mtETH,
        hostEid: hostChainInfo.lzChainId,
    });

    // VM.add(
    //     await buildBalancer(hre, DEPLOYMENT_NAMES.TOFT_BALANCER, [
    //         DEPLOY_CONFIG.MISC[chainInfo.chainId]!.STARGATE_ROUTER_ETH,
    //         DEPLOY_CONFIG.MISC[chainInfo.chainId]!.STARGATE_ROUTER,
    //         DEPLOY_CONFIG.MISC[chainInfo.chainId]!.STARGATE_ROUTER,
    //         owner,
    //     ]),
    // );

    if (isHostChain) {
        // VM Add tWSTETH
        await VMAddToftWithArgs({
            ...taskArgs,
            target: 'mtoft',
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
            target: 'mtoft',
            deploymentName: DEPLOYMENT_NAMES.tRETH,
            erc20: DEPLOY_CONFIG.POST_LBP[chainInfo.chainId]!.reth,
            name: 'Tapioca OFT Rocket Pool Ether',
            symbol: DEPLOYMENT_NAMES.tRETH,
            noModuleDeploy: true,
            hostEid: hostChainInfo.lzChainId,
        });
    }

    // VM Add BB + SGL OFTs
    if (isHostChain) {
        console.log('\n[+] Adding tOFT contracts');
        // VM Add tETH
        await VMAddToftWithArgs({
            ...taskArgs,
            target: 'toft',
            deploymentName: DEPLOYMENT_NAMES.tETH,
            erc20: DEPLOY_CONFIG.POST_LBP[chainInfo.chainId]!.WETH,
            name: 'Tapioca OFT Wrapped Ether',
            symbol: DEPLOYMENT_NAMES.tETH,
            noModuleDeploy: true, // Modules are loaded here
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

    if (isSideChain) {
        console.log('\n[+] Adding tOFT contracts');

        // VM Add sDAI
        await VMAddToftWithArgs({
            ...taskArgs,
            target: 'toft',
            deploymentName: DEPLOYMENT_NAMES.tsDAI,
            erc20: DEPLOY_CONFIG.POST_LBP[chainInfo.chainId]!.sDAI,
            name: 'Tapioca OFT Staked DAI',
            symbol: DEPLOYMENT_NAMES.tsDAI,
            noModuleDeploy: true,
            hostEid: sdaiSideChain.lzChainId,
        });
    }
}
