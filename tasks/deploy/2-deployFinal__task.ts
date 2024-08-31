import * as TAPIOCA_BAR_CONFIG from '@tapioca-bar/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import {
    loadGlobalContract,
    loadLocalContract,
    setLzPeer__task,
} from 'tapioca-sdk';
import { TTapiocaDeployerVmPass } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { DEPLOYMENT_NAMES } from './DEPLOY_CONFIG';
import { TToftDeployerTaskArgs, VMAddToft } from './toftDeployer__task';
import { TAPIOCA_PROJECTS_NAME } from '@tapioca-sdk/api/config';
import { findGlobalDeployment } from '@tapioca-sdk/api/db';

/**
 * @notice Should be called after Bar post lbp side chain deployment
 * @notice Should be called on Mainnet as main chain an Arbitrum as side chain
 *
 * Deploys: Arb, Eth
 * - Tapioca OFT SGL DAI Market
 *
 * Post deploy: Arb, Eth
 * - LZPeer link the SGL DAI Market OFT xChain
 */
export const deployFinal__task = async (
    _taskArgs: TToftDeployerTaskArgs & { sdaiMarketChainName: string },
    hre: HardhatRuntimeEnvironment,
) => {
    await hre.SDK.DeployerVM.tapiocaDeployTask(
        _taskArgs,
        {
            hre,
            // // Static simulation needs to be false, constructor relies on external call. We're using 0x00 replacement with DeployerVM, which creates a false positive for static simulation.
            staticSimulation: false,
            // bytecodeSizeLimit: 80_000,
            // overrideOptions: {
            //     gasLimit: 10_000_000,
            // },
        },
        tapiocaDeployTask,
        tapiocaPostDeployTask,
    );
};

async function tapiocaPostDeployTask(
    params: TTapiocaDeployerVmPass<{ sdaiMarketChainName: string }>,
) {
    const { hre, taskArgs, chainInfo } = params;
    const { tag } = taskArgs;

    await setLzPeer__task(
        { tag, targetName: DEPLOYMENT_NAMES.T_SGL_SDAI_MARKET },
        hre,
    );
}

async function tapiocaDeployTask(
    params: TTapiocaDeployerVmPass<{ sdaiMarketChainName: string }>,
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
    const { tag, sdaiMarketChainName } = taskArgs;

    const VMAddToftWithArgs = async (args: TToftDeployerTaskArgs) =>
        await VMAddToft({
            chainInfo,
            hre,
            isTestnet,
            tapiocaMulticallAddr,
            VM,
            isHostChain,
            isSideChain,
            taskArgs: args,
        });

    if (isHostChain) {
        /**
         *SGL GLP Market OFT on Host chain
         */
        const sglGlpMarket = loadGlobalContract(
            hre,
            TAPIOCA_PROJECTS_NAME.TapiocaBar,
            chainInfo.chainId,
            TAPIOCA_BAR_CONFIG.DEPLOYMENT_NAMES.SGL_S_GLP_MARKET,
            tag,
        ).address;

        await VMAddToftWithArgs({
            ...taskArgs,
            target: 'toft',
            deploymentName: DEPLOYMENT_NAMES.T_SGL_GLP_MARKET,
            erc20: sglGlpMarket,
            name: 'Tapioca OFT SGL GLP Market',
            symbol: DEPLOYMENT_NAMES.T_SGL_GLP_MARKET,
            noModuleDeploy: false,
            hostEid: chainInfo.lzChainId,
        });

        if (isTestnet) {
            /**
             * usdcMockMarketChain from Side chain
             */
            const usdcMockSglMarket = loadGlobalContract(
                hre,
                TAPIOCA_PROJECTS_NAME.TapiocaBar,
                chainInfo.chainId,
                TAPIOCA_BAR_CONFIG.DEPLOYMENT_NAMES.SGL_USDC_MOCK_MARKET,
                tag,
            ).address;

            await VMAddToftWithArgs({
                ...taskArgs,
                target: 'toft',
                deploymentName: DEPLOYMENT_NAMES.T_SGL_USDC_MOCK_MARKET,
                erc20: usdcMockSglMarket,
                name: 'Tapioca OFT SGL USDC Mock Market',
                symbol: DEPLOYMENT_NAMES.T_SGL_USDC_MOCK_MARKET,
                noModuleDeploy: false,
                hostEid: chainInfo.lzChainId,
            });
        }
    }

    /**
     * sDaiMarketChain from Side chain
     */
    const sdaiMarketChain = hre.SDK.utils.getChainBy(
        'name',
        sdaiMarketChainName,
    );

    const sDaiSglMarket = loadGlobalContract(
        hre,
        TAPIOCA_PROJECTS_NAME.TapiocaBar,
        sdaiMarketChain.chainId,
        TAPIOCA_BAR_CONFIG.DEPLOYMENT_NAMES.SGL_S_DAI_MARKET,
        tag,
    ).address;

    await VMAddToftWithArgs({
        ...taskArgs,
        target: 'toft',
        deploymentName: DEPLOYMENT_NAMES.T_SGL_SDAI_MARKET,
        erc20: sDaiSglMarket,
        name: 'Tapioca OFT SGL DAI Market',
        symbol: DEPLOYMENT_NAMES.T_SGL_SDAI_MARKET,
        noModuleDeploy: false,
        hostEid: sdaiMarketChain.lzChainId,
    });
}
