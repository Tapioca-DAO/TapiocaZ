import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { LZ_ENDPOINT, VALID_ADDRESSES } from '../scripts/constants';
import {
    readTOFTDeployments,
    saveTOFTDeployment,
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
    if (!isMainChain) {
        const deployments = readTOFTDeployments();
        const deployment = Object.values(deployments[args.chainid] ?? []).find(
            (e) => e.erc20address === args.erc20,
        );
        if (!deployment) {
            throw new Error(
                `[-] TOFT is not deployed on chain ${args.chainid}`,
            );
        }
    }

    // Get the deploy tx
    console.log('[+] Tx builder');
    const { Tx_deployTapiocaOFT } = useUtils(hre);
    const lzEndpoint = LZ_ENDPOINT[chainID].address;
    const tx = await Tx_deployTapiocaOFT(
        lzEndpoint,
        args.erc20,
        Number(args.chainid),
    );

    // Get the TWrapper
    const twrapper = await hre.ethers.getContractAt(
        'TapiocaWrapper',
        (
            await hre.deployments.get('TapiocaWrapper')
        ).address,
    );
    // Create the TOFT
    console.log('[+] Deploying TOFT, waiting for 12 confirmation');
    await (await twrapper.createTOFT(args.erc20, tx.txData)).wait(12);
    const lastTOFT = await hre.ethers.getContractAt(
        'TapiocaOFT',
        await twrapper.lastTOFT(),
    );
    const name = await lastTOFT.name();
    const address = lastTOFT.address;

    console.log(`[+] Deployed ${name} TOFT at ${address}`);

    saveTOFTDeployment(chainID, [{ name, address, erc20address: args.erc20 }]);

    console.log('[+] Verifying');
    await hre.run('verify:verify', {
        address: lastTOFT.address,
        contract: 'contracts/TapiocaOFT.sol:TapiocaOFT',
        constructorArguments: tx.args,
    });
};
