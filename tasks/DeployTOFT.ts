import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { LZ_ENDPOINT, VALID_ADDRESSES } from '../scripts/constants';
import {
    readTOFTDeployments,
    saveTOFTDeployment,
    useUtils,
} from '../scripts/utils';

export const deployTOFT = async (
    args: {
        chainid: number;
        erc20: string;
    },
    hre: HardhatRuntimeEnvironment,
) => {
    // Verify that the address is valid
    const chainID = await hre.getChainId();
    const erc20Name = VALID_ADDRESSES[chainID]?.[args.erc20];
    if (erc20Name === undefined) {
        throw new Error(`[-] ERC20 not whitelisted: ${args.erc20}]\n`);
    }

    // Verifies already deployed TOFT if not same chain
    const isMainChain = chainID === String(args.chainid);
    if (!isMainChain) {
        const deployments = readTOFTDeployments();
        const deployment = Object.values(deployments[args.chainid]).find(
            (e) => e.address === args.erc20,
        );
        if (!deployment) {
            throw new Error(
                `[-] TOFT is not deployed on chain ${args.chainid}`,
            );
        }
    }

    // Get the deploy tx
    const { Tx_deployTapiocaOFT } = useUtils(hre);
    const lzEndpoint = LZ_ENDPOINT[chainID].address;
    const tx = await Tx_deployTapiocaOFT(lzEndpoint, args.erc20, args.chainid);

    // Get the TWrapper
    const twrapper = await hre.ethers.getContractAt(
        'TapiocaWrapper',
        (
            await hre.deployments.get('TapiocaWrapper')
        ).address,
    );
    // Create the TOFT
    await (await twrapper.createTOFT(args.erc20, tx)).wait();
    const lastTOFT = await twrapper.lastTOFT();

    console.log(`Deployed ${erc20Name} TOFT at ${lastTOFT}`);

    saveTOFTDeployment(chainID, [
        {
            name: erc20Name,
            address: lastTOFT,
        },
    ]);
};
