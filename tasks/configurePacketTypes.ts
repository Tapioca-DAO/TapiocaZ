import fs from 'fs';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { glob, runTypeChain } from 'typechain';
import writeJsonFile from 'write-json-file';


//Arbitrum:
//  npx hardhat configurePacketTypes --network arbitrum_goerli --src 0xc0106C090153F651c5E6e12249412b9e51f8d49d --dst-lz-chain-id 10106
//  npx hardhat configurePacketTypes --network arbitrum_goerli --src 0xc0106C090153F651c5E6e12249412b9e51f8d49d --dst-lz-chain-id 10109
//  npx hardhat configurePacketTypes --network arbitrum_goerli --src 0xc0106C090153F651c5E6e12249412b9e51f8d49d --dst-lz-chain-id 10112
//  npx hardhat configurePacketTypes --network arbitrum_goerli --src 0xd37E276907e76bF25eBaDA04fB2dCe67c8BE5188 --dst-lz-chain-id 10106
//  npx hardhat configurePacketTypes --network arbitrum_goerli --src 0xd429a8F683Aa8D43Aa3CBdDCa93956CBc44c4242 --dst-lz-chain-id 10109
//  npx hardhat configurePacketTypes --network arbitrum_goerli --src 0x4ba186b07cf3C5C4e2aB967d0Daa996dc83Ce30E --dst-lz-chain-id 10112

//Fuji:
//  npx hardhat configurePacketTypes --network fuji_avalanche --src 0x05C0a8C53BED62edf009b8B870fAC065B4cc3533 --dst-lz-chain-id 10143
//  npx hardhat configurePacketTypes --network fuji_avalanche --src 0x05C0a8C53BED62edf009b8B870fAC065B4cc3533 --dst-lz-chain-id 10109
//  npx hardhat configurePacketTypes --network fuji_avalanche --src 0x05C0a8C53BED62edf009b8B870fAC065B4cc3533 --dst-lz-chain-id 10112
//  npx hardhat configurePacketTypes --network fuji_avalanche --src 0x71dDd5ec9815740529D62726Adc50EB84a3A4e1a --dst-lz-chain-id 10143
//  npx hardhat configurePacketTypes --network fuji_avalanche --src 0x628570D3768e7424dd7Ca4671846D1b67c82E141 --dst-lz-chain-id 10109
//  npx hardhat configurePacketTypes --network fuji_avalanche --src 0x33e1eFe92dBca2d45fe131ab3a1613A169696924 --dst-lz-chain-id 10112

//Mumbai:
//  npx hardhat configurePacketTypes --network mumbai --src 0xa1BD6C0B6b35209B3710cA6Ab306736e06C1fe9c --dst-lz-chain-id 10106
//  npx hardhat configurePacketTypes --network mumbai --src 0xa1BD6C0B6b35209B3710cA6Ab306736e06C1fe9c --dst-lz-chain-id 10143
//  npx hardhat configurePacketTypes --network mumbai --src 0xa1BD6C0B6b35209B3710cA6Ab306736e06C1fe9c --dst-lz-chain-id 10112
//  npx hardhat configurePacketTypes --network mumbai --src 0x4172056FDC344b8Fd38bfDe590a7eDdF32cD1d55 --dst-lz-chain-id 10143
//  npx hardhat configurePacketTypes --network mumbai --src 0x556029CB9c74B07bC34abED41eaA424159463E50 --dst-lz-chain-id 10106
//  npx hardhat configurePacketTypes --network mumbai --src 0x8688820A09b5796840c4570747E7E0064B87d3DF --dst-lz-chain-id 10112

//Fantom 
//  npx hardhat configurePacketTypes --network fantom_testnet --src 0x9C574C71eCabc7aEf19593A595fb9f8Aa6a78bB0 --dst-lz-chain-id 10106
//  npx hardhat configurePacketTypes --network fantom_testnet --src 0x9C574C71eCabc7aEf19593A595fb9f8Aa6a78bB0 --dst-lz-chain-id 10109
//  npx hardhat configurePacketTypes --network fantom_testnet --src 0x9C574C71eCabc7aEf19593A595fb9f8Aa6a78bB0 --dst-lz-chain-id 10143
//  npx hardhat configurePacketTypes --network fantom_testnet --src 0x5Ba1CF78AAEA752BEC33c2036B1E315C881d8E49 --dst-lz-chain-id 10143
//  npx hardhat configurePacketTypes --network fantom_testnet --src 0x177b341C0E1b36f9D4fAC0F90B1ebF3a20480834 --dst-lz-chain-id 10106
//  npx hardhat configurePacketTypes --network fantom_testnet --src 0x5916f519DFB4b80a3aaD07E0530b93605c35C636 --dst-lz-chain-id 10109

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
