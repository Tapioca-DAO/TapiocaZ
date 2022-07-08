import { HardhatRuntimeEnvironment } from 'hardhat/types';
import config from '../hardhat.export';
import { LZ_ENDPOINT, VALID_ADDRESSES } from '../scripts/constants';
import {
    getNetworkFromLzChainId,
    getNetworkNameFromChainId,
    getOtherChainDeployment,
    readTOFTDeployments,
    saveTOFTDeployment,
    TContract,
    useNetwork,
    useUtils,
} from '../scripts/utils';

export const deployTOFT = async (
    args: {
        lzChainId: string;
        erc20: string;
    },
    hre: HardhatRuntimeEnvironment,
) => {
    console.log('[+] Verification');
    args.erc20 = hre.ethers.utils.getAddress(args.erc20); // Normalize

    // Transform lzChainId to network name
    args.lzChainId = String(config.networks[args.lzChainId].lzChainId);
    if (!args.lzChainId) throw new Error('[-] Invalid lzChainId');

    // Verify that the address is valid
    const currentChainID = await hre.getChainId();
    const argsChainId = getNetworkFromLzChainId(args.lzChainId);
    const currentLzChain = LZ_ENDPOINT[currentChainID];

    if (!argsChainId || !currentLzChain)
        throw new Error('[-] Invalid argsChainId or currentLzChain');

    const erc20Name = VALID_ADDRESSES[args.lzChainId]?.[args.erc20];
    if (erc20Name === undefined) {
        throw new Error(`[-] ERC20 not whitelisted: ${args.erc20}]\n`);
    }

    // Verifies already deployed TOFT if not same chain
    const isMainChain = currentLzChain.lzChainId === String(args.lzChainId);
    let mainContract: TContract;
    if (!isMainChain) {
        const deployments = readTOFTDeployments();
        mainContract = Object.values(deployments[args.lzChainId] ?? []).find(
            (e) => e.erc20address === args.erc20,
        ) as TContract;
        if (!mainContract) {
            throw new Error(
                `[-] TOFT is not deployed on chain ${args.lzChainId}`,
            );
        }
    }

    // Setup network, if curr chain is main chain, it's the same, if not then grab the main chain network
    const network =
        currentChainID === argsChainId
            ? hre.network.name
            : getNetworkNameFromChainId(argsChainId);
    if (!network)
        throw new Error(`[-] Network not found for chain ${args.lzChainId}`);

    const networkSigner = await useNetwork(hre, network);

    // Get the deploy tx
    console.log('[+] Tx builder');
    const { Tx_deployTapiocaOFT } = useUtils(hre);
    const tx = await Tx_deployTapiocaOFT(
        currentLzChain.address,
        args.erc20,
        Number(currentLzChain.lzChainId),
        networkSigner,
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
    await (await tWrapper.createTOFT(args.erc20, tx.txData)).wait(12);
    const lastTOFT = await hre.ethers.getContractAt(
        'TapiocaOFT',
        await tWrapper.lastTOFT(),
    );
    const name = await lastTOFT.name();
    const address = lastTOFT.address;

    console.log(`[+] Deployed ${name} TOFT at ${address}`);

    saveTOFTDeployment(currentLzChain.lzChainId, [
        { name, address, erc20address: args.erc20 },
    ]);

    if (!isMainChain) {
        console.log('[+] Setting trusted main chain => other chain');

        // Set trust remote main chain => other chain
        const mainTWrapper = await getOtherChainDeployment(
            hre,
            getNetworkNameFromChainId(argsChainId) ?? '',
            'TapiocaWrapper',
        );
        const txMainChain = lastTOFT.interface.encodeFunctionData(
            'setTrustedRemote',
            [currentLzChain.lzChainId, address],
        );

        await (
            await (
                await hre.ethers.getContractAt(
                    'TapiocaWrapper',
                    mainTWrapper.address,
                )
            )
                .connect(networkSigner)
                .executeTOFT(mainContract!.address ?? '', txMainChain, {
                    gasLimit: 1000000,
                })
        ).wait();

        // Set trust remote other chain => main chain
        console.log('[+] Setting trusted other chain => main chain');

        const txOtherChain = lastTOFT.interface.encodeFunctionData(
            'setTrustedRemote',
            [currentLzChain.lzChainId, mainContract!.address],
        );
        await (
            await tWrapper.executeTOFT(address, txOtherChain, {
                gasLimit: 1000000,
            })
        ).wait();
    }

    console.log('[+] Verifying');
    await hre.run('verify:verify', {
        address: lastTOFT.address,
        contract: 'contracts/TapiocaOFT.sol:TapiocaOFT',
        constructorArguments: tx.args,
    });
};
