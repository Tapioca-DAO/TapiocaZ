import { HardhatRuntimeEnvironment } from 'hardhat/types';

export const setCluster__task = async (
    args: { address: string; cluster: string; oft: boolean },
    hre: HardhatRuntimeEnvironment,
) => {
    const tOFT = args.oft
        ? await hre.ethers.getContractAt('TOFT', args.address)
        : await hre.ethers.getContractAt('mTOFT', args.address);
    await (await tOFT.setCluster(args.cluster)).wait(3);
};
