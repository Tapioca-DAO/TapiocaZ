import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { readTOFTDeployments } from '../scripts/utils';

export const wrap = async (
    args: { toft: string; amount: string },
    hre: HardhatRuntimeEnvironment,
) => {
    const signer = (await hre.ethers.getSigners())[0];
    const toftContract = await hre.ethers.getContractAt(
        'TapiocaOFT',
        args.toft,
    );

    const erc20 = await hre.ethers.getContractAt(
        'ERC20',
        await toftContract.erc20(),
    );

    console.log('[+] Approving');
    await (await erc20.approve(toftContract.address, args.amount)).wait();
    console.log('[+] Wrapping');
    await (await toftContract.wrap(signer.address, args.amount)).wait();
};
