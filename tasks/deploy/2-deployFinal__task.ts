import * as TAPIOCA_BAR_CONFIG from '@tapioca-bar/config';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { loadLocalContract, setLzPeer__task } from 'tapioca-sdk';
import { TTapiocaDeployerVmPass } from 'tapioca-sdk/dist/ethers/hardhat/DeployerVM';
import { DEPLOYMENT_NAMES } from './DEPLOY_CONFIG';
import { TToftDeployerTaskArgs, VMAddToft } from './toftDeployer__task';

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
    _taskArgs: TToftDeployerTaskArgs & { sDaiMarketChainName: string },
    hre: HardhatRuntimeEnvironment,
) => {
    await hre.SDK.DeployerVM.tapiocaDeployTask(
        _taskArgs,
        {
            hre,
            bytecodeSizeLimit: 80_000,
            // Static simulation needs to be false, constructor relies on external call. We're using 0x00 replacement with DeployerVM, which creates a false positive for static simulation.
            staticSimulation: false,
            overrideOptions: {
                gasLimit: 10_000_000,
            },
        },
        tapiocaDeployTask,
        tapiocaPostDeployTask,
    );
};

async function tapiocaPostDeployTask(
    params: TTapiocaDeployerVmPass<{ sDaiMarketChainName: string }>,
) {
    const { hre, taskArgs, chainInfo } = params;
    const { tag } = taskArgs;

    if (
        chainInfo.name === 'ethereum' ||
        chainInfo.name === 'arbitrum' ||
        chainInfo.name === 'optimism' ||
        chainInfo.name === 'sepolia' ||
        chainInfo.name === 'arbitrum_sepolia' ||
        chainInfo.name === 'optimism_sepolia'
    ) {
        await setLzPeer__task(
            { tag, targetName: DEPLOYMENT_NAMES.T_SGL_SDAI_MARKET },
            hre,
        );
    }
}

async function tapiocaDeployTask(
    params: TTapiocaDeployerVmPass<{ sDaiMarketChainName: string }>,
) {
    const { hre, VM, tapiocaMulticallAddr, taskArgs, isTestnet, chainInfo } =
        params;
    const { tag, sDaiMarketChainName } = taskArgs;

    const sdaiMarketChain = hre.SDK.utils.getChainBy(
        'name',
        sDaiMarketChainName,
    );
    const sDaiSglMarket = loadLocalContract(
        hre,
        sdaiMarketChain.chainId,
        TAPIOCA_BAR_CONFIG.DEPLOYMENT_NAMES.SGL_S_DAI_MARKET,
        tag,
    ).address;

    const VMAddToftWithArgs = async (args: TToftDeployerTaskArgs) =>
        await VMAddToft({
            chainInfo,
            hre,
            isTestnet,
            tapiocaMulticallAddr,
            VM,
            taskArgs: args,
        });

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
