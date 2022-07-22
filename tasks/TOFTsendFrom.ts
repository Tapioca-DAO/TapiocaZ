import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { LZ_ENDPOINTS } from '../scripts/constants';
import { readTOFTDeployments } from '../scripts/utils';
import { TapiocaOFT } from '../typechain';

export const toftSendFrom = async (
    args: { toft: string; to: string; amount: string },
    hre: HardhatRuntimeEnvironment,
) => {
    const signer = (await hre.ethers.getSigners())[0];

    const chainId = await hre.getChainId();
    const lzChain = LZ_ENDPOINTS[chainId];

    const deployments = readTOFTDeployments();
    const toft = deployments[lzChain.lzChainId].find(
        (e) => e.address === args.toft,
    );

    if (!toft) throw new Error(`[-] TOFT not deployed on chain ${chainId}`);
    const otherChainId = Object.keys(deployments).find((e) =>
        deployments[e].find(
            (o) =>
                o.erc20address === toft?.erc20address &&
                o.address !== args.toft,
        ),
    );
    if (!otherChainId) throw new Error('[-] TOFT not deployed on other chain');
    const otherChainTOFT = deployments[otherChainId!].find(
        (e) => e.erc20address === toft?.erc20address,
    );
    if (!otherChainTOFT)
        throw new Error(
            `[-] TOFT not not found on other chain ${otherChainId}`,
        );

    const toftContract = await hre.ethers.getContractAt(
        'TapiocaOFT',
        toft.address,
    );

    const sendFromParam: Parameters<TapiocaOFT['sendFrom']> = [
        signer.address,
        otherChainId,
        args.to,
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

    const lzEndpoint = await hre.ethers.getContractAt(
        'LZEndpointMock',
        LZ_ENDPOINTS[chainId].address,
    );

    const feeEstimation = await lzEndpoint.estimateFees(
        LZ_ENDPOINTS[chainId].lzChainId,
        otherChainTOFT.address,
        payload,
        false,
        '0x',
    );

    await (
        await signer.sendTransaction({
            to: toft.address,
            value: feeEstimation._nativeFee,
            data: payload,
        })
    ).wait();
};
