import { getChainBy } from '@tapioca-sdk/api/utils';
import { TTapiocaDeployTaskArgs } from '@tapioca-sdk/ethers/hardhat/DeployerVM';
import { TapiocaMulticall } from '@tapioca-sdk/typechain/tapioca-periphery';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { loadLocalContract, loadLocalContractOnAllChains } from 'tapioca-sdk';
import { TContractWithChainInfo } from 'tapioca-sdk/dist/ethers/utils';

import { DEPLOYMENT_NAMES } from 'tasks/deploy/DEPLOY_CONFIG';

// Does not support ERC20s, only gas token mTOFT
export const balancerInnitConnectedOft__task = async (
    _taskArgs: TTapiocaDeployTaskArgs & {
        targetName: string;
    },
    hre: HardhatRuntimeEnvironment,
) => {
    console.log(
        `[+] Setting Balancer connected OFT for ${_taskArgs.targetName}...`,
    );
    const chain = hre.SDK.utils.getChainBy('chainId', hre.SDK.eChainId);
    const { targetName, tag } = _taskArgs;
    const isTestnet = !!chain.tags.find((e) => e === 'testnet');
    const deployments = loadLocalContractOnAllChains(
        hre,
        targetName,
        tag,
        isTestnet,
    );

    if (deployments.length === 0) {
        throw new Error(
            `[-] No deployment found for contract ${targetName} on tag ${tag}`,
        );
    }

    for (const targetDep of deployments) {
        const targetChain = getChainBy('chainId', targetDep.chainInfo.chainId);
        await hre.SDK.hardhatUtils.useNetwork(hre, targetChain.name); // Need to switch network to the target chain
        const VM = hre.SDK.DeployerVM.loadVM({ hre, tag }); // Need to load the VM for every chainID to get the right multicall instance

        console.log(`\t[+] Setting connected OFT on ${targetChain.name}...`);
        const calls = await populateCalls(hre, tag, targetDep, deployments);
        await VM.executeMulticall(calls);
    }

    // Switch back to the original network
    console.log(`[+] connected OFT setting for ${targetName} done!`);
    await hre.SDK.hardhatUtils.useNetwork(hre, chain.name);
};

async function populateCalls(
    hre: HardhatRuntimeEnvironment,
    tag: string,
    targetDep: TContractWithChainInfo,
    deployments: TContractWithChainInfo[],
) {
    const balancer = await hre.ethers.getContractAt(
        'Balancer',
        loadLocalContract(
            hre,
            hre.SDK.eChainId,
            DEPLOYMENT_NAMES.TOFT_BALANCER,
            tag,
        ).address,
    );

    const calls: TapiocaMulticall.CallStruct[] = [];
    const peers = deployments.filter(
        (e) => targetDep.chainInfo.chainId !== e.chainInfo.chainId,
    ); // Filter out the target chain
    for (const peer of peers) {
        console.log(`\t\t[+] Setting peer for ${peer.chainInfo.name}...`);
        calls.push({
            target: balancer.address,
            callData: balancer.interface.encodeFunctionData(
                'initConnectedOFT',
                [
                    targetDep.deployment.address,
                    peer.chainInfo.lzChainId,
                    peer.deployment.address,
                    '',
                    // Add _bytes memory _ercData to support ERC20
                ],
            ),
            allowFailure: false,
        });
    }
    return calls;
}
