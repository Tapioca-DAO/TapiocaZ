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
//ex: npx hardhat deployTOFT --network arbitrum_goerli --erc20 0x7B30C951cFF9B5648A08FeC08A588e3b143a095B --yield-box 0x93cF32C5fF98c0758b32dF9F6DB9e4f4faaCe736 --salt TESTTOFT --host-chain-name arbitrum_goerli
//ex: npx hardhat deployTOFT --network fuji_avalanche --erc20 0x7B30C951cFF9B5648A08FeC08A588e3b143a095B --yield-box 0x538c2189ea266069031622e70441bc73A613e9Ed --salt TESTTOFT --host-chain-name arbitrum_goerli
//ex: npx hardhat deployTOFT --network mumbai --erc20 0x7B30C951cFF9B5648A08FeC08A588e3b143a095B --yield-box 0xF0a07d15F4F6FCB919EE410B10D8ab282eD1107F --salt TESTTOFT --host-chain-name arbitrum_goerli
//ex: npx hardhat deployTOFT --network fantom_testnet --erc20 0x7B30C951cFF9B5648A08FeC08A588e3b143a095B --yield-box 0xA24eaCCd49f0dFB8Eb8629CB7E8Ee956173A4293 --salt TESTTOFT --host-chain-name arbitrum_goerli

//ex: npx hardhat deployTOFT --network fuji_avalanche --erc20 0xDfb0eE3A7de3AFc394aEB63AC5761e615e8FA692 --yield-box 0x538c2189ea266069031622e70441bc73A613e9Ed --salt TESTTOFT --host-chain-name fuji_avalanche
//ex: npx hardhat deployTOFT --network arbitrum_goerli --erc20 0xDfb0eE3A7de3AFc394aEB63AC5761e615e8FA692 --yield-box 0x93cF32C5fF98c0758b32dF9F6DB9e4f4faaCe736 --salt TESTTOFT --host-chain-name fuji_avalanche
//ex: npx hardhat deployTOFT --network mumbai --erc20 0xDfb0eE3A7de3AFc394aEB63AC5761e615e8FA692 --yield-box 0xF0a07d15F4F6FCB919EE410B10D8ab282eD1107F --salt TESTTOFT --host-chain-name fuji_avalanche
//ex: npx hardhat deployTOFT --network fantom_testnet --erc20 0xDfb0eE3A7de3AFc394aEB63AC5761e615e8FA692 --yield-box 0xA24eaCCd49f0dFB8Eb8629CB7E8Ee956173A4293 --salt TESTTOFT --host-chain-name fuji_avalanche

//ex: npx hardhat deployTOFT --network mumbai --erc20 0xd682F81b03764D872c271BeD4020610eb48f41e3 --yield-box 0xF0a07d15F4F6FCB919EE410B10D8ab282eD1107F --salt TESTTOFT --host-chain-name mumbai
//ex: npx hardhat deployTOFT --network fuji_avalanche --erc20 0xd682F81b03764D872c271BeD4020610eb48f41e3 --yield-box 0x538c2189ea266069031622e70441bc73A613e9Ed --salt TESTTOFT --host-chain-name mumbai
//ex: npx hardhat deployTOFT --network arbitrum_goerli --erc20 0xd682F81b03764D872c271BeD4020610eb48f41e3 --yield-box 0x93cF32C5fF98c0758b32dF9F6DB9e4f4faaCe736 --salt TESTTOFT --host-chain-name mumbai
//ex: npx hardhat deployTOFT --network fantom_testnet --erc20 0xd682F81b03764D872c271BeD4020610eb48f41e3 --yield-box 0xA24eaCCd49f0dFB8Eb8629CB7E8Ee956173A4293 --salt TESTTOFT --host-chain-name mumbai

//ex: npx hardhat deployTOFT --network fantom_testnet --erc20 0xd9da4265fa5957a119c4fC8c36a36b5e50eDc33B --yield-box 0xA24eaCCd49f0dFB8Eb8629CB7E8Ee956173A4293 --salt TESTTOFT --host-chain-name fantom_testnet
//ex: npx hardhat deployTOFT --network arbitrum_goerli --erc20 0xd9da4265fa5957a119c4fC8c36a36b5e50eDc33B --yield-box 0x93cF32C5fF98c0758b32dF9F6DB9e4f4faaCe736 --salt TESTTOFT --host-chain-name fantom_testnet
//ex: npx hardhat deployTOFT --network fuji_avalanche --erc20 0xd9da4265fa5957a119c4fC8c36a36b5e50eDc33B --yield-box 0x538c2189ea266069031622e70441bc73A613e9Ed --salt TESTTOFT --host-chain-name fantom_testnet
//ex: npx hardhat deployTOFT --network mumbai --erc20 0xd9da4265fa5957a119c4fC8c36a36b5e50eDc33B --yield-box 0xF0a07d15F4F6FCB919EE410B10D8ab282eD1107F --salt TESTTOFT --host-chain-name fantom_testnet

export const deployTOFT__task = async (
    args: {
        erc20: string;
        yieldBox: string;
        salt: string;
        hostChainName: string;
        linkedTOFT: boolean;
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

    const currentChainId: any = await hre.getChainId();

    // Load up chain meta.
    const hostChain = handleGetChainBy('name', args.hostChainName);
    const currentChain = handleGetChainBy('chainId', currentChainId);
    const hostChainNetworkSigner = await useNetwork(hre, hostChain.name);
    const isMainChain = hostChain.chainId === currentChain.chainId;

    // Load ERC20 meta now that we have the host chain signer and knows if we're on the host chain.
    console.log('[+] Load ERC20');
    const erc20 = await hre.ethers.getContractAt('ERC20', deploymentMetadata.erc20.address, hostChainNetworkSigner);
    deploymentMetadata.erc20.name = await erc20.name();

    // Verifies that the TOFT contract is deployed on the host chain if we're currently not on it.
    let hostChainTOFT!: TContract;
    if (!isMainChain) {
        console.log('[+] Retrieving host chain tOFT');
        hostChainTOFT = getTOFTDeploymentByERC20Address(hostChain.chainId, deploymentMetadata.erc20.address);
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
    const tWrapper = await hre.ethers.getContractAt('TapiocaWrapper', (await hre.deployments.get('TapiocaWrapper')).address);

    // Create the TOFT
    console.log('[+] Deploying TOFT, waiting for 6 confirmation');
    await (
        await tWrapper.createTOFT(args.erc20, tx.txData, hre.ethers.utils.formatBytes32String(args.salt), args.linkedTOFT ?? false)
    ).wait(6);

    // We save the TOFT deployment
    const latestTOFT = await hre.ethers.getContractAt('TapiocaOFT', await tWrapper.lastTOFT());
    const TOFTMeta: TContract = {
        name: await latestTOFT.name(),
        address: latestTOFT.address,
        meta: {
            ...deploymentMetadata,
            hostChain: {
                id: hostChain.chainId,
                address: isMainChain ? latestTOFT.address : hostChainTOFT.address,
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
        const hostDepl = getTOFTDeploymentByERC20Address(TOFTMeta.meta.hostChain.id, TOFTMeta.meta.erc20.address);
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
        console.log('[+] Setting trusted remotes');
        // hostChain[currentChain] = true
        await setTrustedRemote(hre, hostChain.chainId, currentChain.chainId, hostChainTOFT.address, latestTOFT.address);

        // otherChain[hostChain] = true
        await setTrustedRemote(hre, currentChain.chainId, hostChain.chainId, latestTOFT.address, hostChainTOFT.address);

        console.log('[+] Configuring packets');
        //linked => host
        await configure(hre, latestTOFT.address, currentChain.chainId, hostChain.chainId);
        //host => linked
        await configure(hre, hostChainTOFT.address, hostChain.chainId, currentChain.chainId);
    }
};
async function configure(hre: HardhatRuntimeEnvironment, currentOft: string, currentChainId: string, toChainId: string) {
    const fromChain = handleGetChainBy('chainId', currentChainId);
    const toChain = handleGetChainBy('chainId', toChainId);
    const signer = await useNetwork(hre, fromChain.name);

    const packetTypes = [1, 2, 770, 771, 772, 773];

    const tWrapper = await hre.ethers.getContractAt(
        'TapiocaWrapper',
        (
            await getDeploymentByChain(hre, fromChain.name, 'TapiocaWrapper')
        ).address,
    );

    for (let i = 0; i < packetTypes.length; i++) {
        const encodedTX = (await hre.ethers.getContractFactory('TapiocaOFT')).interface.encodeFunctionData('setMinDstGas', [
            toChain.lzChainId,
            packetTypes[i],
            200000,
        ]);

        await (await tWrapper.connect(signer).executeTOFT(currentOft, encodedTX, true)).wait();

        const useAdaptersTx = (await hre.ethers.getContractFactory('TapiocaOFT')).interface.encodeFunctionData(
            'setUseCustomAdapterParams',
            [true],
        );

        await (await tWrapper.connect(signer).executeTOFT(currentOft, useAdaptersTx, true)).wait();
    }
}

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

    console.log(`[+] Setting (${toChain.name}) as a trusted remote on (${fromChain.name})`);

    const trustedRemotePath = hre.ethers.utils.solidityPack(['address', 'address'], [toTOFTAddress, fromToft]);
    const encodedTX = (await hre.ethers.getContractFactory('TapiocaOFT')).interface.encodeFunctionData('setTrustedRemote', [
        toChain.lzChainId,
        trustedRemotePath,
    ]);

    const tWrapper = await hre.ethers.getContractAt(
        'TapiocaWrapper',
        (
            await getDeploymentByChain(hre, fromChain.name, 'TapiocaWrapper')
        ).address,
    );

    await (await tWrapper.connect(signer).executeTOFT(fromToft, encodedTX, true)).wait();
}
