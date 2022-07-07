import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { LZ_ENDPOINT, VALID_ADDRESSES } from '../scripts/constants';
import {
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
        chainid: string;
        erc20: string;
    },
    hre: HardhatRuntimeEnvironment,
) => {
    console.log('[+] Verification');
    args.erc20 = hre.ethers.utils.getAddress(args.erc20); // Normalize

    // Verify that the address is valid
    const chainID = await hre.getChainId();
    const erc20Name = VALID_ADDRESSES[args.chainid]?.[args.erc20];
    if (erc20Name === undefined) {
        throw new Error(`[-] ERC20 not whitelisted: ${args.erc20}]\n`);
    }

    // Verifies already deployed TOFT if not same chain
    const isMainChain = chainID === String(args.chainid);
    let mainContract: TContract;
    if (!isMainChain) {
        const deployments = readTOFTDeployments();
        mainContract = Object.values(deployments[args.chainid] ?? []).find(
            (e) => e.erc20address === args.erc20,
        ) as TContract;
        if (!mainContract) {
            throw new Error(
                `[-] TOFT is not deployed on chain ${args.chainid}`,
            );
        }
    }

    // Setup network, if in main chain it's the same, if not then grab the main chain network
    const network =
        (await hre.getChainId()) === args.chainid
            ? hre.network.name
            : getNetworkNameFromChainId(args.chainid);
    if (!network)
        throw new Error(`[-] Network not found for chain ${args.chainid}`);

    const networkSigner = await useNetwork(hre, network);

    // Get the deploy tx
    console.log('[+] Tx builder');
    const { Tx_deployTapiocaOFT } = useUtils(hre);
    const lzEndpoint = LZ_ENDPOINT[chainID].address;
    const tx = await Tx_deployTapiocaOFT(
        lzEndpoint,
        args.erc20,
        Number(args.chainid),
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

    saveTOFTDeployment(chainID, [{ name, address, erc20address: args.erc20 }]);

    if (!isMainChain) {
        console.log('[+] Setting trusted main chain => other chain');

        // Set trust remote main chain => other chain
        const mainTWrapper = await getOtherChainDeployment(
            hre,
            getNetworkNameFromChainId(args.chainid) ?? '',
            'TapiocaWrapper',
        );
        const txMainChain = lastTOFT.interface.encodeFunctionData(
            'setTrustedRemote',
            [LZ_ENDPOINT[chainID].lzChainId, address],
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
            [LZ_ENDPOINT[args.chainid].lzChainId, mainContract!.address],
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
