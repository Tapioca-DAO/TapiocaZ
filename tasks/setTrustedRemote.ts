import fs from 'fs';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { glob, runTypeChain } from 'typechain';
import writeJsonFile from 'write-json-file';

//10106-fuji
//10109-mumbai
//10143-arb_goerli

//  tAVAX
//npx hardhat setTrustedRemote --network arbitrum_goerli --chain 10106 --dst 0x28D691380D2d8C86f6fdD2e49123C1DA9fa33b32 --src 0xef0871E0e8C3320f5Cf8c0051EC856b9c083660f
//npx hardhat setTrustedRemote --network arbitrum_goerli --chain 10109 --dst 0x74FC744146cb0067AC34DF10c6e7bcc050439D37 --src 0xef0871E0e8C3320f5Cf8c0051EC856b9c083660f

//npx hardhat setTrustedRemote --network fuji_avalanche --chain 10143 --dst 0xef0871E0e8C3320f5Cf8c0051EC856b9c083660f --src 0x28D691380D2d8C86f6fdD2e49123C1DA9fa33b32
//npx hardhat setTrustedRemote --network fuji_avalanche --chain 10109 --dst 0x74FC744146cb0067AC34DF10c6e7bcc050439D37 --src 0x28D691380D2d8C86f6fdD2e49123C1DA9fa33b32

//npx hardhat setTrustedRemote --network mumbai --chain 10143 --dst 0xef0871E0e8C3320f5Cf8c0051EC856b9c083660f --src 0x74FC744146cb0067AC34DF10c6e7bcc050439D37
//npx hardhat setTrustedRemote --network mumbai --chain 10106 --dst 0x28D691380D2d8C86f6fdD2e49123C1DA9fa33b32 --src 0x74FC744146cb0067AC34DF10c6e7bcc050439D37
//---

//  tWETH
//npx hardhat setTrustedRemote --network arbitrum_goerli --chain 10106 --dst 0x4ee2C3e02D9c47951a6a56bE803030D70F3dbfb7 --src 0xd5d5d2fed1eCb5Dea28Fe81fB575c9C241448D71
//npx hardhat setTrustedRemote --network arbitrum_goerli --chain 10109 --dst 0xAa7e77fb38C8B5df58cba3a49227dAb6ee5f18Cb --src 0xd5d5d2fed1eCb5Dea28Fe81fB575c9C241448D71

//npx hardhat setTrustedRemote --network fuji_avalanche --chain 10143 --dst 0xd5d5d2fed1eCb5Dea28Fe81fB575c9C241448D71 --src 0x4ee2C3e02D9c47951a6a56bE803030D70F3dbfb7
//npx hardhat setTrustedRemote --network fuji_avalanche --chain 10109 --dst 0xAa7e77fb38C8B5df58cba3a49227dAb6ee5f18Cb --src 0x4ee2C3e02D9c47951a6a56bE803030D70F3dbfb7

//npx hardhat setTrustedRemote --network mumbai --chain 10143 --dst 0xd5d5d2fed1eCb5Dea28Fe81fB575c9C241448D71 --src 0xAa7e77fb38C8B5df58cba3a49227dAb6ee5f18Cb
//npx hardhat setTrustedRemote --network mumbai --chain 10106 --dst 0x4ee2C3e02D9c47951a6a56bE803030D70F3dbfb7 --src 0xAa7e77fb38C8B5df58cba3a49227dAb6ee5f18Cb
//---

//  tMatic
//npx hardhat setTrustedRemote --network arbitrum_goerli --chain 10106 --dst 0xe82f613C2B46D3fD51bA2A6Bc04a4dB65413b2a1 --src 0x48d95D182D33990910DC39868Da6FcA59182626c
//npx hardhat setTrustedRemote --network arbitrum_goerli --chain 10109 --dst 0x18BC2Be450e04EBB72A150dfa9a268F60302215c --src 0x48d95D182D33990910DC39868Da6FcA59182626c

//npx hardhat setTrustedRemote --network fuji_avalanche --chain 10143 --dst 0x48d95D182D33990910DC39868Da6FcA59182626c --src 0xe82f613C2B46D3fD51bA2A6Bc04a4dB65413b2a1
//npx hardhat setTrustedRemote --network fuji_avalanche --chain 10109 --dst 0x18BC2Be450e04EBB72A150dfa9a268F60302215c --src 0xe82f613C2B46D3fD51bA2A6Bc04a4dB65413b2a1

//npx hardhat setTrustedRemote --network mumbai --chain 10143 --dst 0x48d95D182D33990910DC39868Da6FcA59182626c --src 0x18BC2Be450e04EBB72A150dfa9a268F60302215c
//npx hardhat setTrustedRemote --network mumbai --chain 10106 --dst 0xe82f613C2B46D3fD51bA2A6Bc04a4dB65413b2a1 --src 0x18BC2Be450e04EBB72A150dfa9a268F60302215c
//---

// tFtm -todo
//npx hardhat setTrustedRemote --network fuji_avalanche --chain 10112 --dst 0x9C574C71eCabc7aEf19593A595fb9f8Aa6a78bB0 --src 0x33e1eFe92dBca2d45fe131ab3a1613A169696924
//npx hardhat setTrustedRemote --network fantom_testnet --chain 10106 --dst 0x33e1eFe92dBca2d45fe131ab3a1613A169696924 --src 0x9C574C71eCabc7aEf19593A595fb9f8Aa6a78bB0

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
