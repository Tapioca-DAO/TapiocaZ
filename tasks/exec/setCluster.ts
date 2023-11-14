import { HardhatRuntimeEnvironment } from 'hardhat/types';

export const setCluster__task = async (
    args: { toft: string; cluster: string },
    hre: HardhatRuntimeEnvironment,
) => {
    const toftContract = await hre.ethers.getContractAt(
        'TapiocaOFT',
        args.toft,
    );

    await (await toftContract.setCluster(args.cluster)).wait(3);
};
