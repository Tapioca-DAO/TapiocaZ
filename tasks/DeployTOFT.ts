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
import { constants } from '../deploy/utils';
import { updateDeployments } from '../deploy/utils';

/**
 *
 * Deploy a TOFT contract to the specified network. It'll also deploy it to Tapioca host chain (Optimism, chainID 10).
 * A record will be added to the `DEPLOYMENTS_PATH` file.
 *
 * @param args.erc20 - The address of the ERC20.
 * @param args.yieldBox - The address of YieldBox.
 * @param args.salt - The salt used for CREATE2 deployment
 * @param args.hostChainName - The host chain name of the ERC20.
 */
//ex: npx hardhat deployTOFT --network arbitrum_goerli --erc20 0xd428690148436dA9c7422698eEe15F51C8cec871 --yield-box 0xFCdE8366705e8A9c1eDE4C56D716c9e7564CE50D --salt TESTTOFT --host-chain-name arbitrum_goerli
//ex: npx hardhat deployTOFT --network fuji_avalanche --erc20 0xd428690148436dA9c7422698eEe15F51C8cec871 --yield-box 0x2CCFd66f76E73EEF0Ac76D7C03d0E367a03B7B2e --salt TESTTOFT --host-chain-name arbitrum_goerli
//ex: npx hardhat deployTOFT --network mumbai --erc20 0xd428690148436dA9c7422698eEe15F51C8cec871 --yield-box 0x3E6c224326e77F417636e10c74c7dC797B7c2bB1 --salt TESTTOFT --host-chain-name arbitrum_goerli

//ex: npx hardhat deployTOFT --network fuji_avalanche --erc20 0x667e8fB73Ba84599Dc1A8d7e1A0f003CF1A8Db76 --yield-box 0x2CCFd66f76E73EEF0Ac76D7C03d0E367a03B7B2e --salt TESTTOFT --host-chain-name fuji_avalanche
//ex: npx hardhat deployTOFT --network arbitrum_goerli --erc20 0x667e8fB73Ba84599Dc1A8d7e1A0f003CF1A8Db76 --yield-box 0xFCdE8366705e8A9c1eDE4C56D716c9e7564CE50D --salt TESTTOFT --host-chain-name fuji_avalanche
//ex: npx hardhat deployTOFT --network mumbai --erc20 0x667e8fB73Ba84599Dc1A8d7e1A0f003CF1A8Db76 --yield-box 0x3E6c224326e77F417636e10c74c7dC797B7c2bB1 --salt TESTTOFT --host-chain-name fuji_avalanche

//ex: npx hardhat deployTOFT --network mumbai --erc20 0xb110284648691B5944b8E7c7cfB140e501f77d1C --yield-box 0x3E6c224326e77F417636e10c74c7dC797B7c2bB1 --salt TESTTOFT --host-chain-name mumbai
//ex: npx hardhat deployTOFT --network fuji_avalanche --erc20 0xb110284648691B5944b8E7c7cfB140e501f77d1C --yield-box 0x2CCFd66f76E73EEF0Ac76D7C03d0E367a03B7B2e --salt TESTTOFT --host-chain-name mumbai
//ex: npx hardhat deployTOFT --network arbitrum_goerli --erc20 0xb110284648691B5944b8E7c7cfB140e501f77d1C --yield-box 0xFCdE8366705e8A9c1eDE4C56D716c9e7564CE50D --salt TESTTOFT --host-chain-name mumbai

export const deployTOFT__task = async (
    args: {
        erc20: string;
        yieldBox: string;
        salt: string;
        hostChainName: string;
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
        yieldBox: {
            name: 'YieldBox',
            address: hre.ethers.utils.getAddress(args.yieldBox),
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
    console.log('[+] Load ERC20');
    const erc20 = await hre.ethers.getContractAt(
        'ERC20',
        deploymentMetadata.erc20.address,
        hostChainNetworkSigner,
    );
    deploymentMetadata.erc20.name = await erc20.name();

    // Verifies that the TOFT contract is deployed on the host chain if we're currently not on it.
    let hostChainTOFT!: TContract;
    if (!isMainChain) {
        console.log('[+] Retrieving host chain tOFT');
        hostChainTOFT = getTOFTDeploymentByERC20Address(
            hostChain.chainId,
            deploymentMetadata.erc20.address,
        );
    }

    // Get the deploy tx
    console.log('[+] Building the deploy transaction');
    const tx = await utils.Tx_deployTapiocaOFT(
        currentChain.address,
        false,
        deploymentMetadata.erc20.address,
        deploymentMetadata.yieldBox.address,
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
    console.log('[+] Deploying TOFT, waiting for 6 confirmation');
    await (
        await tWrapper.createTOFT(
            args.erc20,
            tx.txData,
            hre.ethers.utils.formatBytes32String(args.salt),
            false,
        )
    ).wait(6);

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
            linkedChain: [
                {
                    id: !isMainChain ? currentChain.chainId : '',
                    address: !isMainChain ? latestTOFT.address : '',
                },
            ],
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
        hostDepl.meta.linkedChain.push(TOFTMeta.meta.linkedChain[0]);
        saveTOFTDeployment(hostDepl.meta.hostChain.id, [hostDepl]);
    }

    console.log('[+] Verifying the contract on the block explorer');
    try {
        await hre.run('verify:verify', {
            address: latestTOFT.address,
            contract: 'contracts/TapiocaOFT.sol:TapiocaOFT',
            constructorArguments: tx.args,
        });
    } catch {
        console.log('Failed to verify');
    }

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

    const trustedRemotePath = hre.ethers.utils.solidityPack(
        ['address', 'address'],
        [toTOFTAddress, fromToft],
    );
    const encodedTX = (
        await hre.ethers.getContractFactory('TapiocaOFT')
    ).interface.encodeFunctionData('setTrustedRemote', [
        toChain.lzChainId,
        trustedRemotePath,
    ]);

    const tWrapper = await hre.ethers.getContractAt(
        'TapiocaWrapper',
        (
            await getDeploymentByChain(hre, fromChain.name, 'TapiocaWrapper')
        ).address,
    );

    await (
        await tWrapper.connect(signer).executeTOFT(fromToft, encodedTX, true)
    ).wait();
}
