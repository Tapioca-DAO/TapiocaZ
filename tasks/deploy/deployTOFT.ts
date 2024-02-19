import {
    EChainID,
    ELZChainID,
    TAPIOCA_PROJECTS_NAME,
} from '@tapioca-sdk/api/config';

import { HardhatRuntimeEnvironment } from 'hardhat/types';

import { useNetwork } from '../../scripts/utils';
import { loadVM } from '../utils';
import { CHAIN_TOFTS, STARGATE_ROUTER } from './DEPLOY_CONFIG';
import { buildTOFT } from '../deployBuilds/buildTOFT';
import { buildMTOFT } from '../deployBuilds/buildMTOFT';
import { buildTOFTSenderModule } from '../deployBuilds/buildTOFTSenderModule';
import { buildTOFTReceiverModule } from '../deployBuilds/buildTOFTReceiverModule';
import { buildTOFTMarketReceiverModule } from '../deployBuilds/buildTOFTMarketReceiverModule';
import { buildTOFTOptionsReceiverModule } from '../deployBuilds/buildTOFTOptionsReceiverModule';
import { buildTOFTGenericReceiverModule } from '../deployBuilds/buildTOFTGenericReceiverModule';

export const deployTOFT__task = async (
    args: {
        tag?: string;
        onHost?: boolean;
        overrideOptions?: boolean;
    },
    hre: HardhatRuntimeEnvironment,
) => {
    console.log('\n[+] Initiating TOFT deployment');

    const tag = args.tag ?? 'default';
    const project = hre.SDK.config.TAPIOCA_PROJECTS[8];

    const VM = await loadVM(hre, tag);

    const signer = (await hre.ethers.getSigners())[0];

    const chainInfo = hre.SDK.utils.getChainBy(
        'chainId',
        await hre.getChainId(),
    );
    const yieldBox = hre.SDK.db.findGlobalDeployment(
        TAPIOCA_PROJECTS_NAME.YieldBox,
        chainInfo!.chainId,
        'YieldBox',
        tag,
    );
    if (!yieldBox) {
        throw '[-] YieldBox not found';
    }
    console.log('[+] YieldBox found');

    const cluster = hre.SDK.db.findGlobalDeployment(
        TAPIOCA_PROJECTS_NAME.TapiocaPeriphery,
        chainInfo!.chainId,
        'Cluster',
        tag,
    );
    if (!cluster) {
        throw '[-] Cluster not found';
    }
    console.log('[+] Cluster found');

    const tokensArr = args.onHost
        ? CHAIN_TOFTS[chainInfo?.chainId].HOST_TOKENS
        : CHAIN_TOFTS[chainInfo?.chainId].CONNECTED_TOKENS;
    const tokensCounts = tokensArr.length;
    console.log(
        `[+] Deploying for ${
            args.onHost ? 'host tokens' : 'non-host tokens'
        }. Found ${tokensCounts} tokens`,
    );

    /**
     * Deploy on HOST
     */
    if (args.onHost) {
        console.log('[+] Deploying on HOST');
        const tokensArr = CHAIN_TOFTS[chainInfo?.chainId].HOST_TOKENS;

        for (let i = 0; i < tokensArr.length; i++) {
            const token = tokensArr[i];
            const isMTOFT = token == hre.ethers.constants.AddressZero;

            const initStruct = await buildInitStruct(
                hre,
                isMTOFT,
                token,
                chainInfo,
                cluster.address,
                yieldBox.address,
                signer.address,
                false,
            );
            await deployTOFT(hre, tag, initStruct, chainInfo?.chainId, isMTOFT);
        }

        await VM.execute(3);
        await VM.save();
        await VM.verify();

        console.log('[+] TOFTs deloyed on HOST');
    }

    /**
     * Deploy on CONNECTED_CHAINS
     */
    if (!args.onHost) {
        console.log('[+] Deploying on CONNECTED_CHAINS');
        const connectedChainsArr =
            CHAIN_TOFTS[chainInfo?.chainId].CONNECTED_CHAINS;
        for (const chain in connectedChainsArr) {
            const tokensArr = connectedChainsArr[chain];

            for (let i = 0; i < tokensArr.length; i++) {
                const token = tokensArr[i];
                const isMTOFT = token == hre.ethers.constants.AddressZero;

                const initStruct = await buildInitStruct(
                    hre,
                    isMTOFT,
                    token,
                    chainInfo,
                    cluster.address,
                    yieldBox.address,
                    signer.address,
                    true,
                    chain,
                );
                await deployTOFT(
                    hre,
                    tag,
                    initStruct,
                    chainInfo?.chainId,
                    isMTOFT,
                );
            }
        }

        await VM.execute(3);
        await VM.save();
        await VM.verify();

        console.log('[+] TOFTs deloyed on CONNECTED_CHAINS');
    }
};

async function buildInitStruct(
    hre: HardhatRuntimeEnvironment,
    isMTOFT: boolean,
    token: string,
    chainInfo: any,
    clusterAddress: string,
    ybAddress: string,
    owner: string,
    isConnectedChain: boolean,
    hostChainId?: string,
) {
    let toftName = 'TapiocaOFT Native';
    let toftSymbol = 'tNative';
    if (!isMTOFT) {
        if (isConnectedChain) {
            const hostChainInfo = hre.SDK.utils.getChainBy(
                'chainId',
                hostChainId!,
            );
            const network = await useNetwork(hre, hostChainInfo?.name);
            const erc20 = await hre.ethers.getContractAt(
                'ERC20',
                token,
                network,
            );
            toftName = `TapiocaOFT ${await erc20.name()}`;
            toftSymbol = `t${await erc20.symbol()}`;
        } else {
            const erc20 = await hre.ethers.getContractAt('ERC20', token);
            toftName = `TapiocaOFT ${await erc20.name()}`;
            toftSymbol = `t${await erc20.symbol()}`;
        }
    }

    return {
        name: toftName,
        symbol: toftSymbol,
        endpoint: chainInfo?.address,
        owner: owner,
        yieldBox: ybAddress,
        cluster: clusterAddress,
        erc20: token,
        hostEid: chainInfo?.lzChainId,
    };
}

async function deployTOFT(
    hre: HardhatRuntimeEnvironment,
    tag: string,
    initStruct: any,
    chainId: any,
    isMTOFT: boolean,
) {
    const modulesStruct = await createTOFTModules(
        hre,
        initStruct.name,
        tag,
        chainId,
        initStruct,
    );

    const VM = await loadVM(hre, tag);
    if (isMTOFT) {
        VM.add(
            await buildMTOFT(
                hre,
                initStruct.name,
                [initStruct, modulesStruct, STARGATE_ROUTER[chainId]],
                [],
            ),
        );
    } else {
        VM.add(
            await buildTOFT(
                hre,
                initStruct.name,
                [initStruct, modulesStruct],
                [],
            ),
        );
    }
}

async function createTOFTModules(
    hre: HardhatRuntimeEnvironment,
    name: string,
    tag: string,
    chainId: any,
    initStruct: any,
) {
    const modulesVM = await loadVM(hre, tag);

    console.log('[+] Deploy TOFT modules');

    const randName = (Math.random() + 1).toString(36).substring(2);

    modulesVM.add(
        await buildTOFTSenderModule(
            hre,
            `${name} - SenderModule - ${randName}`,
            Object.values(initStruct),
        ),
    );
    modulesVM.add(
        await buildTOFTReceiverModule(
            hre,
            `${name} - ReceiverModule - ${randName}`,
            Object.values(initStruct),
        ),
    );
    modulesVM.add(
        await buildTOFTMarketReceiverModule(
            hre,
            `${name} - MarketReceiverModule - ${randName}`,
            Object.values(initStruct),
        ),
    );
    modulesVM.add(
        await buildTOFTOptionsReceiverModule(
            hre,
            `${name} - OptionsReceiverModule - ${randName}`,
            Object.values(initStruct),
        ),
    );
    modulesVM.add(
        await buildTOFTGenericReceiverModule(
            hre,
            `${name} - GenericReceiverModule - ${randName}`,
            Object.values(initStruct),
        ),
    );

    // Add and execute
    await modulesVM.execute(3);
    await modulesVM.save();
    await modulesVM.verify();

    const senderModule = hre.SDK.db.findLocalDeployment(
        chainId,
        `${name} - SenderModule - ${randName}`,
        tag,
    );
    const receiverModule = hre.SDK.db.findLocalDeployment(
        chainId,
        `${name} - ReceiverModule - ${randName}`,
        tag,
    );
    const marketReceiverModule = hre.SDK.db.findLocalDeployment(
        chainId,
        `${name} - MarketReceiverModule - ${randName}`,
        tag,
    );
    const optionsReceiverModule = hre.SDK.db.findLocalDeployment(
        chainId,
        `${name} - OptionsReceiverModule - ${randName}`,
        tag,
    );
    const genericReceiverModule = hre.SDK.db.findLocalDeployment(
        chainId,
        `${name} - GenericReceiverModule - ${randName}`,
        tag,
    );

    console.log('[+] Modules deployed');

    return {
        tOFTSenderModule: senderModule.address,
        tOFTReceiverModule: receiverModule.address,
        marketReceiverModule: marketReceiverModule.address,
        optionsReceiverModule: optionsReceiverModule.address,
        genericReceiverModule: genericReceiverModule.address,
    };
}
