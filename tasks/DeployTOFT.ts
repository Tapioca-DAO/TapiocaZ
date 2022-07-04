import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { LZ_ENDPOINT, VALID_ADDRESSES } from '../scripts/constants';
import { saveTOFTDeployment, useUtils } from '../scripts/utils';
import { TapiocaWrapper } from '../typechain';

export const deployTOFT = async (
    args: {
        chainid: number;
        erc20?: string;
    },
    hre: HardhatRuntimeEnvironment,
) => {
    args.erc20 = args.erc20
        ? args.erc20
        : '0x0000000000000000000000000000000000000000';

    // Verify that the address is valid
    const chainID = await hre.getChainId();
    const erc20Name = VALID_ADDRESSES[chainID]?.[args.erc20];
    if (erc20Name === undefined) {
        throw new Error(`[-] ERC20 not whitelisted: ${args.erc20}]\n`);
    }

    // Get the deploy tx
    const { Tx_deployTapiocaOFT } = useUtils(hre);
    const lzEndpoint = LZ_ENDPOINT[chainID].address;
    const tx = await Tx_deployTapiocaOFT(lzEndpoint, args.erc20, args.chainid);

    // Get the TWrapper
    const twrapper = (await hre.deployments.get(
        'TapiocaWrapper',
    )) as unknown as TapiocaWrapper;

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
