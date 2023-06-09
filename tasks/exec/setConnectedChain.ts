import { HardhatRuntimeEnvironment } from 'hardhat/types';

//npx hardhat setConnectedChain --toft 0x33D8A80e43018E1Ee577F9DdE6777ebeEb12650c --chain 43113 --status true --network arbitrum_goerli
export const setConnectedChain__task = async (
    args: { toft: string; chain: string; status: boolean },
    hre: HardhatRuntimeEnvironment,
) => {
    const toftContract = await hre.ethers.getContractAt(
        'mTapiocaOFT',
        args.toft,
    );

    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const currentChainId = String(hre.network.config.chainId);
    const wrapperDeployment = hre.SDK.db.getLocalDeployment(
        currentChainId,
        'TapiocaWrapper',
        tag,
    );

    if (!wrapperDeployment) {
        throw new Error('[-] TapiocaWrapper not found');
    }

    console.log('[+] TapiocaWrapper found');

    const wrapperContract = await hre.ethers.getContractAt(
        'TapiocaWrapper',
        wrapperDeployment.address,
    );
    const txData = toftContract.interface.encodeFunctionData(
        'updateConnectedChain',
        [args.chain, args.status],
    );
    await wrapperContract.executeTOFT(toftContract.address, txData, true);
    console.log('[+] Connected chain status updated');
};
