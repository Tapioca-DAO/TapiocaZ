import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { LZ_ENDPOINT, VALID_ADDRESSES } from '../scripts/constants';
import { saveTOFTDeployment, useUtils } from '../scripts/utils';
import { TapiocaWrapper } from '../typechain';

export const deployTOFT = async (
    args: {
        mainChainID: number;
        erc20Address?: string;
    },
    hre: HardhatRuntimeEnvironment,
) => {
    args.erc20Address = args.erc20Address
        ? args.erc20Address
        : '0x0000000000000000000000000000000000000000';

    // Verify that the address is valid
    const chainID = await hre.getChainId();
    const erc20Name = VALID_ADDRESSES[chainID][args.erc20Address];
    if (erc20Name === undefined) {
        throw new Error(`Invalid ERC20 address: ${args.erc20Address}`);
    }

    // Get the deploy tx
    const { Tx_deployTapiocaOFT } = useUtils(hre);
    const lzEndpoint = LZ_ENDPOINT[chainID].address;
    const tx = await Tx_deployTapiocaOFT(
        lzEndpoint,
        args.erc20Address,
        args.mainChainID,
    );

    // Get the TWrapper
    const twrapper = (await hre.deployments.get(
        'TapiocaWrapper',
    )) as unknown as TapiocaWrapper;

    // Create the TOFT
    await (await twrapper.createTOFT(args.erc20Address, tx)).wait();
    const lastTOFT = await twrapper.lastTOFT();

    console.log(`Deployed ${erc20Name} TOFT at ${lastTOFT}`);

    saveTOFTDeployment(chainID, [
        {
            name: erc20Name,
            address: lastTOFT,
        },
    ]);
};
