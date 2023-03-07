import fs from 'fs';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { glob, runTypeChain } from 'typechain';
import writeJsonFile from 'write-json-file';

//10106-fuji
//10109-mumbai
//10143-arb_goerli

//arb
//  npx hardhat setTrustedRemote --network arbitrum_goerli --chain 10109 --dst 0x4172056FDC344b8Fd38bfDe590a7eDdF32cD1d55 --src 0xc0106C090153F651c5E6e12249412b9e51f8d49d
//  npx hardhat setTrustedRemote --network arbitrum_goerli --chain 10106 --dst 0x71dDd5ec9815740529D62726Adc50EB84a3A4e1a --src 0xc0106C090153F651c5E6e12249412b9e51f8d49d
//  npx hardhat setTrustedRemote --network arbitrum_goerli --chain 10112 --dst 0x5Ba1CF78AAEA752BEC33c2036B1E315C881d8E49 --src 0xc0106C090153F651c5E6e12249412b9e51f8d49d
//  npx hardhat setTrustedRemote --network arbitrum_goerli --chain 10106 --dst 0x628570D3768e7424dd7Ca4671846D1b67c82E141 --src 0xd429a8F683Aa8D43Aa3CBdDCa93956CBc44c4242
//  npx hardhat setTrustedRemote --network arbitrum_goerli --chain 10109 --dst 0xa1BD6C0B6b35209B3710cA6Ab306736e06C1fe9c --src 0xd429a8F683Aa8D43Aa3CBdDCa93956CBc44c4242
//  npx hardhat setTrustedRemote --network arbitrum_goerli --chain 10112 --dst 0x5916f519DFB4b80a3aaD07E0530b93605c35C636 --src 0xd429a8F683Aa8D43Aa3CBdDCa93956CBc44c4242
//  npx hardhat setTrustedRemote --network arbitrum_goerli --chain 10106 --dst 0x05C0a8C53BED62edf009b8B870fAC065B4cc3533 --src 0xd37E276907e76bF25eBaDA04fB2dCe67c8BE5188
//  npx hardhat setTrustedRemote --network arbitrum_goerli --chain 10109 --dst 0x556029CB9c74B07bC34abED41eaA424159463E50 --src 0xd37E276907e76bF25eBaDA04fB2dCe67c8BE5188
//  npx hardhat setTrustedRemote --network arbitrum_goerli --chain 10112 --dst 0x177b341C0E1b36f9D4fAC0F90B1ebF3a20480834 --src 0xd37E276907e76bF25eBaDA04fB2dCe67c8BE5188
//  npx hardhat setTrustedRemote --network arbitrum_goerli --chain 10112 --dst 0x9C574C71eCabc7aEf19593A595fb9f8Aa6a78bB0 --src 0x4ba186b07cf3C5C4e2aB967d0Daa996dc83Ce30E
//  npx hardhat setTrustedRemote --network arbitrum_goerli --chain 10109 --dst 0x8688820A09b5796840c4570747E7E0064B87d3DF --src 0x4ba186b07cf3C5C4e2aB967d0Daa996dc83Ce30E
//  npx hardhat setTrustedRemote --network arbitrum_goerli --chain 10106 --dst 0x33e1eFe92dBca2d45fe131ab3a1613A169696924 --src 0x4ba186b07cf3C5C4e2aB967d0Daa996dc83Ce30E

//fuji
//npx hardhat setTrustedRemote --network fuji_avalanche --chain 10143 --dst 0xd37E276907e76bF25eBaDA04fB2dCe67c8BE5188 --src 0x05C0a8C53BED62edf009b8B870fAC065B4cc3533
//npx hardhat setTrustedRemote --network fuji_avalanche --chain 10109 --dst 0x556029CB9c74B07bC34abED41eaA424159463E50 --src 0x05C0a8C53BED62edf009b8B870fAC065B4cc3533
//npx hardhat setTrustedRemote --network fuji_avalanche --chain 10112 --dst 0x177b341C0E1b36f9D4fAC0F90B1ebF3a20480834 --src 0x05C0a8C53BED62edf009b8B870fAC065B4cc3533
//npx hardhat setTrustedRemote --network fuji_avalanche --chain 10143 --dst 0xc0106C090153F651c5E6e12249412b9e51f8d49d --src 0x71dDd5ec9815740529D62726Adc50EB84a3A4e1a
//npx hardhat setTrustedRemote --network fuji_avalanche --chain 10109 --dst 0x4172056FDC344b8Fd38bfDe590a7eDdF32cD1d55 --src 0x71dDd5ec9815740529D62726Adc50EB84a3A4e1a
//npx hardhat setTrustedRemote --network fuji_avalanche --chain 10112 --dst 0x5Ba1CF78AAEA752BEC33c2036B1E315C881d8E49 --src 0x71dDd5ec9815740529D62726Adc50EB84a3A4e1a
//npx hardhat setTrustedRemote --network fuji_avalanche --chain 10143 --dst 0xd429a8F683Aa8D43Aa3CBdDCa93956CBc44c4242 --src 0x628570D3768e7424dd7Ca4671846D1b67c82E141
//npx hardhat setTrustedRemote --network fuji_avalanche --chain 10109 --dst 0xa1BD6C0B6b35209B3710cA6Ab306736e06C1fe9c --src 0x628570D3768e7424dd7Ca4671846D1b67c82E141
//npx hardhat setTrustedRemote --network fuji_avalanche --chain 10112 --dst 0x5916f519DFB4b80a3aaD07E0530b93605c35C636 --src 0x628570D3768e7424dd7Ca4671846D1b67c82E141
//npx hardhat setTrustedRemote --network fuji_avalanche --chain 10112 --dst 0x9C574C71eCabc7aEf19593A595fb9f8Aa6a78bB0 --src 0x33e1eFe92dBca2d45fe131ab3a1613A169696924
//npx hardhat setTrustedRemote --network fuji_avalanche --chain 10143 --dst 0x4ba186b07cf3C5C4e2aB967d0Daa996dc83Ce30E --src 0x33e1eFe92dBca2d45fe131ab3a1613A169696924
//npx hardhat setTrustedRemote --network fuji_avalanche --chain 10109 --dst 0x8688820A09b5796840c4570747E7E0064B87d3DF --src 0x33e1eFe92dBca2d45fe131ab3a1613A169696924

//mumbai
//npx hardhat setTrustedRemote --network mumbai --chain 10143 --dst 0xd429a8F683Aa8D43Aa3CBdDCa93956CBc44c4242 --src 0xa1BD6C0B6b35209B3710cA6Ab306736e06C1fe9c
//npx hardhat setTrustedRemote --network mumbai --chain 10106 --dst 0x628570D3768e7424dd7Ca4671846D1b67c82E141 --src 0xa1BD6C0B6b35209B3710cA6Ab306736e06C1fe9c
//npx hardhat setTrustedRemote --network mumbai --chain 10112 --dst 0x5916f519DFB4b80a3aaD07E0530b93605c35C636 --src 0xa1BD6C0B6b35209B3710cA6Ab306736e06C1fe9c
//npx hardhat setTrustedRemote --network mumbai --chain 10143 --dst 0xc0106C090153F651c5E6e12249412b9e51f8d49d --src 0x4172056FDC344b8Fd38bfDe590a7eDdF32cD1d55
//npx hardhat setTrustedRemote --network mumbai --chain 10106 --dst 0x71dDd5ec9815740529D62726Adc50EB84a3A4e1a --src 0x4172056FDC344b8Fd38bfDe590a7eDdF32cD1d55
//npx hardhat setTrustedRemote --network mumbai --chain 10112 --dst 0x5Ba1CF78AAEA752BEC33c2036B1E315C881d8E49 --src 0x4172056FDC344b8Fd38bfDe590a7eDdF32cD1d55
//npx hardhat setTrustedRemote --network mumbai --chain 10143 --dst 0xd37E276907e76bF25eBaDA04fB2dCe67c8BE5188 --src 0x556029CB9c74B07bC34abED41eaA424159463E50
//npx hardhat setTrustedRemote --network mumbai --chain 10106 --dst 0x05C0a8C53BED62edf009b8B870fAC065B4cc3533 --src 0x556029CB9c74B07bC34abED41eaA424159463E50
//npx hardhat setTrustedRemote --network mumbai --chain 10112 --dst 0x177b341C0E1b36f9D4fAC0F90B1ebF3a20480834 --src 0x556029CB9c74B07bC34abED41eaA424159463E50
//npx hardhat setTrustedRemote --network mumbai --chain 10112 --dst 0x9C574C71eCabc7aEf19593A595fb9f8Aa6a78bB0 --src 0x8688820A09b5796840c4570747E7E0064B87d3DF
//npx hardhat setTrustedRemote --network mumbai --chain 10106 --dst 0x33e1eFe92dBca2d45fe131ab3a1613A169696924 --src 0x8688820A09b5796840c4570747E7E0064B87d3DF
//npx hardhat setTrustedRemote --network mumbai --chain 10143 --dst 0x4ba186b07cf3C5C4e2aB967d0Daa996dc83Ce30E --src 0x8688820A09b5796840c4570747E7E0064B87d3DF

//fantom
//npx hardhat setTrustedRemote --network fantom_testnet --chain 10143 --dst 0x4ba186b07cf3C5C4e2aB967d0Daa996dc83Ce30E --src 0x9C574C71eCabc7aEf19593A595fb9f8Aa6a78bB0
//npx hardhat setTrustedRemote --network fantom_testnet --chain 10106 --dst 0x33e1eFe92dBca2d45fe131ab3a1613A169696924 --src 0x9C574C71eCabc7aEf19593A595fb9f8Aa6a78bB0
//npx hardhat setTrustedRemote --network fantom_testnet --chain 10109 --dst 0x8688820A09b5796840c4570747E7E0064B87d3DF --src 0x9C574C71eCabc7aEf19593A595fb9f8Aa6a78bB0
//npx hardhat setTrustedRemote --network fantom_testnet --chain 10143 --dst 0xc0106C090153F651c5E6e12249412b9e51f8d49d --src 0x5Ba1CF78AAEA752BEC33c2036B1E315C881d8E49
//npx hardhat setTrustedRemote --network fantom_testnet --chain 10106 --dst 0x71dDd5ec9815740529D62726Adc50EB84a3A4e1a --src 0x5Ba1CF78AAEA752BEC33c2036B1E315C881d8E49
//npx hardhat setTrustedRemote --network fantom_testnet --chain 10109 --dst 0x4172056FDC344b8Fd38bfDe590a7eDdF32cD1d55 --src 0x5Ba1CF78AAEA752BEC33c2036B1E315C881d8E49
//npx hardhat setTrustedRemote --network fantom_testnet --chain 10106 --dst 0x05C0a8C53BED62edf009b8B870fAC065B4cc3533 --src 0x177b341C0E1b36f9D4fAC0F90B1ebF3a20480834
//npx hardhat setTrustedRemote --network fantom_testnet --chain 10109 --dst 0x556029CB9c74B07bC34abED41eaA424159463E50 --src 0x177b341C0E1b36f9D4fAC0F90B1ebF3a20480834
//npx hardhat setTrustedRemote --network fantom_testnet --chain 10143 --dst 0xd37E276907e76bF25eBaDA04fB2dCe67c8BE5188 --src 0x177b341C0E1b36f9D4fAC0F90B1ebF3a20480834
//npx hardhat setTrustedRemote --network fantom_testnet --chain 10109 --dst 0xa1BD6C0B6b35209B3710cA6Ab306736e06C1fe9c --src 0x5916f519DFB4b80a3aaD07E0530b93605c35C636
//npx hardhat setTrustedRemote --network fantom_testnet --chain 10106 --dst 0x628570D3768e7424dd7Ca4671846D1b67c82E141 --src 0x5916f519DFB4b80a3aaD07E0530b93605c35C636
//npx hardhat setTrustedRemote --network fantom_testnet --chain 10143 --dst 0xd429a8F683Aa8D43Aa3CBdDCa93956CBc44c4242 --src 0x5916f519DFB4b80a3aaD07E0530b93605c35C636
export const setTrustedRemote__task = async (
    taskArgs: { chain: string; dst: string; src: string },
    hre: HardhatRuntimeEnvironment,
) => {
    console.log('\nRetrieving tOFT');
    const tOFTContract = await hre.ethers.getContractAt(
        'TapiocaOFT',
        taskArgs.src,
    );

    const path = hre.ethers.utils.solidityPack(
        ['address', 'address'],
        [taskArgs.dst, taskArgs.src],
    );
    console.log(`Setting trusted remote with path ${path}`);

    const encodedTX = (
        await hre.ethers.getContractFactory('TapiocaOFT')
    ).interface.encodeFunctionData('setTrustedRemote', [taskArgs.chain, path]);

    const tWrapper = await hre.ethers.getContractAt(
        'TapiocaWrapper',

        await tOFTContract.tapiocaWrapper(),
    );

    await (
        await tWrapper.executeTOFT(tOFTContract.address, encodedTX, true)
    ).wait();

    console.log('Done');
};
