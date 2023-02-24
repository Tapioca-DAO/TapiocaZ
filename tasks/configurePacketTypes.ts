import fs from 'fs';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { glob, runTypeChain } from 'typechain';
import writeJsonFile from 'write-json-file';

//Arbitrum:
//  npx hardhat configurePacketTypes --network arbitrum_goerli --src 0xc0106C090153F651c5E6e12249412b9e51f8d49d --dst-lz-chain-id 10106
//  npx hardhat configurePacketTypes --network arbitrum_goerli --src 0xc0106C090153F651c5E6e12249412b9e51f8d49d --dst-lz-chain-id 10109

//Fuji:
//  npx hardhat configurePacketTypes --network fuji_avalanche --src 0x05C0a8C53BED62edf009b8B870fAC065B4cc3533 --dst-lz-chain-id 10143
//  npx hardhat configurePacketTypes --network fuji_avalanche --src 0x05C0a8C53BED62edf009b8B870fAC065B4cc3533 --dst-lz-chain-id 10109

//Mumbai:
//  npx hardhat configurePacketTypes --network mumbai --src 0xa1BD6C0B6b35209B3710cA6Ab306736e06C1fe9c --dst-lz-chain-id 10106
//  npx hardhat configurePacketTypes --network mumbai --src 0xa1BD6C0B6b35209B3710cA6Ab306736e06C1fe9c --dst-lz-chain-id 10143

//Fantom 
//  npx hardhat configurePacketTypes --network fantom_testnet --src 0x9C574C71eCabc7aEf19593A595fb9f8Aa6a78bB0 --dst-lz-chain-id 10106
//  npx hardhat configurePacketTypes --network fuji_avalanche --src 0x33e1eFe92dBca2d45fe131ab3a1613A169696924 --dst-lz-chain-id 10112

export const configurePacketTypes__task = async (
    taskArgs: { src: string; dstLzChainId: string },
    hre: HardhatRuntimeEnvironment,
) => {
    const packetTypes = [0, 1, 2, 770, 771, 772, 773];

    const tOFTContract = await hre.ethers.getContractAt(
        'TapiocaOFT',
        taskArgs.src,
    );

    const wrapperAddress = await tOFTContract.tapiocaWrapper();
    const tWrapper = await hre.ethers.getContractAt(
        'TapiocaWrapper',
        wrapperAddress,
    );

    for (var i = 0; i < packetTypes.length; i++) {
        let encodedTX = (
            await hre.ethers.getContractFactory('TapiocaOFT')
        ).interface.encodeFunctionData('setMinDstGas', [
            taskArgs.dstLzChainId,
            packetTypes[i],
            200000,
        ]);

        await (
            await tWrapper.executeTOFT(tOFTContract.address, encodedTX, true)
        ).wait();

        let useAdaptersTx = (
            await hre.ethers.getContractFactory('TapiocaOFT')
        ).interface.encodeFunctionData('setUseCustomAdapterParams', [true]);

        await (
            await tWrapper.executeTOFT(
                tOFTContract.address,
                useAdaptersTx,
                true,
            )
        ).wait();
    }
    console.log('\nDone');
};
