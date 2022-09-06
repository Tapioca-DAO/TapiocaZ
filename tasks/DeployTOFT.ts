import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { TContract, TMeta } from '../constants';
import {
    generateSalt,
    getDeploymentByChain,
    getTOFTDeploymentByERC20Address,
    handleGetChainBy,
    removeTOFTDeployment,
    saveTOFTDeployment,
    useNetwork,
    useUtils,
} from '../scripts/utils';
/**
 *
 * Deploy a TOFT contract to the specified network. It'll also deploy it to Tapioca host chain (Optimism, chainID 10).
 * A record will be added to the `DEPLOYMENTS_PATH` file.
 *
 * @param args.hostChainName - The host chain name of the ERC20.
 * @param args.erc20 - The address of the ERC20.
 */
export const deployTOFT = async (
    args: {
        hostChainName: string;
        erc20: string;
    },
    hre: HardhatRuntimeEnvironment,
) => {
    console.log('[+] Initializing');
    const utils = useUtils(hre);

    const deploymentMetadata: TMeta = {
        // We'll fill empty properties later.
        erc20: {
            name: '',
            address: hre.ethers.utils.getAddress(args.erc20), // Normalize
        },
        hostChain: {
            id: '',
            address: '',
        },
        linkedChain: {
            id: '',
            address: '',
        },
    };

    // Load up chain meta.
    const hostChain = handleGetChainBy('name', args.hostChainName);
    const currentChain = handleGetChainBy('chainId', await hre.getChainId());
    const hostChainNetworkSigner = await useNetwork(hre, hostChain.name);

    const isMainChain = hostChain.chainId === currentChain.chainId;

    // Load ERC20 meta now that we have the host chain signer and knows if we're on the host chain.
    const erc20 = await hre.ethers.getContractAt(
        'ERC20',
        deploymentMetadata.erc20.address,
        hostChainNetworkSigner,
    );
    deploymentMetadata.erc20.name = await erc20.name();

    // Verifies that the TOFT contract is deployed on the host chain if we're currently not on it.
    let hostChainTOFT!: TContract;
    if (!isMainChain) {
        hostChainTOFT = getTOFTDeploymentByERC20Address(
            hostChain.chainId,
            deploymentMetadata.erc20.address,
        );
    }

    // Get the deploy tx
    console.log('[+] Building the deploy transaction');
    const tx = await utils.Tx_deployTapiocaOFT(
        currentChain.address,
        deploymentMetadata.erc20.address,
        Number(hostChain.chainId),
        hostChainNetworkSigner,
    );

    // Get the tWrapper
    const tWrapper = await hre.ethers.getContractAt(
        'TapiocaWrapper',
        (
            await hre.deployments.get('TapiocaWrapper')
        ).address,
    );

    // Create the TOFT
    console.log('[+] Deploying TOFT, waiting for 12 confirmation');
    await (
        await tWrapper.createTOFT(args.erc20, tx.txData, generateSalt())
    ).wait(12);

    // We save the TOFT deployment
    const latestTOFT = await hre.ethers.getContractAt(
        'TapiocaOFT',
        await tWrapper.lastTOFT(),
    );
    const TOFTMeta: TContract = {
        name: await latestTOFT.name(),
        address: latestTOFT.address,
        meta: {
            ...deploymentMetadata,
            hostChain: {
                id: hostChain.chainId,
                address: isMainChain
                    ? latestTOFT.address
                    : hostChainTOFT.address,
            },
            // First write off the host chain TOFT deployment meta will not include the linkedChain info since it is not known yet.
            linkedChain: {
                id: !isMainChain ? currentChain.chainId : '',
                address: !isMainChain ? latestTOFT.address : '',
            },
        },
    };
    console.log(`[+] Deployed ${TOFTMeta.name} TOFT at ${TOFTMeta.address}`);
    saveTOFTDeployment(currentChain.chainId, [TOFTMeta]);

    // Now that we know linked chain info, we update the host chain TOFT deployment meta.
    if (!isMainChain) {
        const hostDepl = getTOFTDeploymentByERC20Address(
            TOFTMeta.meta.hostChain.id,
            TOFTMeta.meta.erc20.address,
        );
        removeTOFTDeployment(hostDepl.meta.hostChain.id, hostDepl);
        hostDepl.meta.linkedChain = TOFTMeta.meta.linkedChain;
        saveTOFTDeployment(hostDepl.meta.hostChain.id, [hostDepl]);
    }

    console.log('[+] Verifying the contract on the block explorer');
    await hre.run('verify:verify', {
        address: latestTOFT.address,
        contract: 'contracts/TapiocaOFT.sol:TapiocaOFT',
        constructorArguments: tx.args,
    });

    // Finally, we set the trusted remotes between the chains if we have 2 deployments.
    if (!isMainChain) {
        // hostChain[currentChain] = true
        await setTrustedRemote(
            hre,
            hostChain.chainId,
            currentChain.chainId,
            hostChainTOFT.address,
            latestTOFT.address,
        );

        // otherChain[hostChain] = true
        await setTrustedRemote(
            hre,
            currentChain.chainId,
            hostChain.chainId,
            latestTOFT.address,
            hostChainTOFT.address,
        );
    }
};

async function setTrustedRemote(
    hre: HardhatRuntimeEnvironment,
    fromChainId: string,
    toChainId: string,
    fromToft: string,
    toTOFTAddress: string,
) {
    const fromChain = handleGetChainBy('chainId', fromChainId);
    const signer = await useNetwork(hre, fromChain.name);
    const toChain = handleGetChainBy('chainId', toChainId);

    console.log(
        `[+] Setting (${toChain.name}) as a trusted remote on (${fromChain.name})`,
    );

    const encodedTX = (
        await hre.ethers.getContractFactory('TapiocaOFT')
    ).interface.encodeFunctionData('setTrustedRemote', [
        toChain.lzChainId,
        toTOFTAddress,
    ]);

    const tWrapper = await hre.ethers.getContractAt(
        'TapiocaWrapper',
        (
            await getDeploymentByChain(hre, fromChain.name, 'TapiocaWrapper')
        ).address,
    );

    await (
        await tWrapper.connect(signer).executeTOFT(fromToft, encodedTX, true, {
            gasLimit: 200_000,
        })
    ).wait();
}
