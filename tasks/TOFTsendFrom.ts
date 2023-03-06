import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { getTOFTDeploymentByTOFTAddress, handleGetChainBy } from '../scripts/utils';
import { TapiocaOFT } from '../typechain';

export const toftSendFrom = async (args: { toft: string; to: 'host' | 'linked'; amount: string }, hre: HardhatRuntimeEnvironment) => {
    if (args.to !== 'host' && args.to !== 'linked') {
        throw new Error('[-] Invalid `to` argument');
    }

    console.log('[+] Initializing');
    const signer = (await hre.ethers.getSigners())[0];

    const currentChain = handleGetChainBy('chainId', await hre.getChainId());

    const toftDeployment = getTOFTDeploymentByTOFTAddress(currentChain.chainId, args.toft);

    if (
        (args.to === 'host' && toftDeployment.meta.hostChain.id === currentChain.chainId) ||
        (args.to === 'linked' && toftDeployment.meta.linkedChain.id === currentChain.chainId)
    ) {
        throw new Error('[-] TOFT can not be sent to the same current chain');
    }

    const dstTOFT = args.to === 'host' ? toftDeployment.meta.hostChain.address : toftDeployment.meta.linkedChain.address;

    const toftContract = await hre.ethers.getContractAt('TapiocaOFT', toftDeployment.address);

    console.log('[+] Building TX');
    const sendFromParam: Parameters<TapiocaOFT['sendFrom']> = [
        signer.address,
        toftDeployment.meta.linkedChain.id,
        dstTOFT,
        args.amount,
        signer.address,
        signer.address,
        '0x',
    ];
    const payload = toftContract.interface.encodeFunctionData(
        // eslint-disable-next-line @typescript-eslint/ban-ts-comment
        // @ts-ignore
        'sendFrom',
        sendFromParam,
    );

    const lzEndpoint = await hre.ethers.getContractAt('LZEndpointMock', currentChain.address);

    const feeEstimation = await lzEndpoint.estimateFees(
        toftDeployment.meta.linkedChain.id,
        toftDeployment.meta.linkedChain.address,
        payload,
        false,
        '0x',
    );

    await (
        await signer.sendTransaction({
            to: toftContract.address,
            value: feeEstimation._nativeFee,
            data: payload,
        })
    ).wait();
};
