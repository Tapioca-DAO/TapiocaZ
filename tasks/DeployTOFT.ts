import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { TContract, TMeta } from '../constants';
import {
    generateSalt,
    getOtherChainDeployment,
    handleGetChainBy,
    readTOFTDeployments,
    saveTOFTDeployment,
    useNetwork,
    useUtils,
} from '../scripts/utils';
/**
 *
 * Deploy a TOFT contract to the specified network. It'll also deploy it to Tapioca host chain (Optimism, chainID 10).
 * A record will be added to the `DEPLOYMENTS_PATH` file.
 *
 * @param args.hostChainId - The host chain ID of the ERC20.
 * @param args.erc20 - The address of the ERC20.
 */
export const deployTOFT = async (
    args: {
        hostChainId: string;
        erc20: string;
    },
    hre: HardhatRuntimeEnvironment,
) => {
    console.log('[+] Initializing');
    const utils = useUtils(hre);

    const erc20Meta: TMeta = {
        name: '', // We'll fill this in later.
        address: hre.ethers.utils.getAddress(args.erc20), // Normalize
    };

    // Load up chain meta.
    const hostChain = handleGetChainBy('chainId', args.hostChainId);
    const currentChain = handleGetChainBy('chainId', await hre.getChainId());
    const hostChainNetworkSigner = await useNetwork(hre, hostChain.name);

    const isMainChain = hostChain.chainId === currentChain.chainId;

    // Load ERC20 meta now that we have the host chain signer and knows if we're on the host chain.
    const erc20 = await hre.ethers.getContractAt(
        'ERC20',
        erc20Meta.address,
        hostChainNetworkSigner,
    );
    erc20Meta.name = await erc20.name();

    // Verifies that the TOFT contract is deployed on the host chain if we're currently not on it.
    let hostChainTOFT!: TContract;
    if (!isMainChain) {
        hostChainTOFT = readTOFTDeployments()[hostChain.chainId].find(
            (e) => e.meta.address === erc20Meta.address,
        ) as TContract;
        if (!hostChainTOFT) {
            throw new Error(`[-] TOFT not deployed on chain ${hostChain.name}`);
        }
    }

    // Get the deploy tx
    console.log('[+] Building the deploy transaction');
    const tx = await utils.Tx_deployTapiocaOFT(
        currentChain.lzChainId,
        erc20Meta.address,
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
        meta: erc20Meta,
    };
    console.log(`[+] Deployed ${TOFTMeta.name} TOFT at ${TOFTMeta.address}`);
    saveTOFTDeployment(currentChain.chainId, [TOFTMeta]);

    console.log('[+] Verifying the contract on the block explorer');
    await hre.run('verify:verify', {
        address: latestTOFT.address,
        contract: 'contracts/TapiocaOFT.sol:TapiocaOFT',
        constructorArguments: tx.args,
    });

    // Finally, we set the trusted remotes between the chains if we have 2 deployments.
    if (isMainChain) {
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
            hostChain.chainId,
            currentChain.chainId,
            hostChainTOFT.address,
            latestTOFT.address,
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
            await getOtherChainDeployment(hre, fromChain.name, 'TapiocaWrapper')
        ).address,
    );

    await (
        await tWrapper.connect(signer).executeTOFT(fromToft, encodedTX, true, {
            gasLimit: 200_000,
        })
    ).wait();
}
