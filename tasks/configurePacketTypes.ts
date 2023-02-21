import fs from 'fs';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { glob, runTypeChain } from 'typechain';
import writeJsonFile from 'write-json-file';

//Arbitrum:
//  npx hardhat configurePacketTypes --network arbitrum_goerli --src 0xd5d5d2fed1eCb5Dea28Fe81fB575c9C241448D71 --dst-lz-chain-id 10106
//  npx hardhat configurePacketTypes --network arbitrum_goerli --src 0xd5d5d2fed1eCb5Dea28Fe81fB575c9C241448D71 --dst-lz-chain-id 10109

//  npx hardhat configurePacketTypes --network arbitrum_goerli --src 0xef0871E0e8C3320f5Cf8c0051EC856b9c083660f --dst-lz-chain-id 10106
//  npx hardhat configurePacketTypes --network arbitrum_goerli --src 0xef0871E0e8C3320f5Cf8c0051EC856b9c083660f --dst-lz-chain-id 10109

//  npx hardhat configurePacketTypes --network arbitrum_goerli --src 0x48d95D182D33990910DC39868Da6FcA59182626c --dst-lz-chain-id 10106
//  npx hardhat configurePacketTypes --network arbitrum_goerli --src 0x48d95D182D33990910DC39868Da6FcA59182626c --dst-lz-chain-id 10109

//Fuji:
//  npx hardhat configurePacketTypes --network fuji_avalanche --src 0x4ee2C3e02D9c47951a6a56bE803030D70F3dbfb7 --dst-lz-chain-id 10143
//  npx hardhat configurePacketTypes --network fuji_avalanche --src 0x4ee2C3e02D9c47951a6a56bE803030D70F3dbfb7 --dst-lz-chain-id 10109

//  npx hardhat configurePacketTypes --network fuji_avalanche --src 0xe82f613C2B46D3fD51bA2A6Bc04a4dB65413b2a1 --dst-lz-chain-id 10143
//  npx hardhat configurePacketTypes --network fuji_avalanche --src 0xe82f613C2B46D3fD51bA2A6Bc04a4dB65413b2a1 --dst-lz-chain-id 10109

//  npx hardhat configurePacketTypes --network fuji_avalanche --src 0x28D691380D2d8C86f6fdD2e49123C1DA9fa33b32 --dst-lz-chain-id 10143
//  npx hardhat configurePacketTypes --network fuji_avalanche --src 0x28D691380D2d8C86f6fdD2e49123C1DA9fa33b32 --dst-lz-chain-id 10109

//Mumbai:
//  npx hardhat configurePacketTypes --network mumbai --src 0xAa7e77fb38C8B5df58cba3a49227dAb6ee5f18Cb --dst-lz-chain-id 10106
//  npx hardhat configurePacketTypes --network mumbai --src 0xAa7e77fb38C8B5df58cba3a49227dAb6ee5f18Cb --dst-lz-chain-id 10143

//  npx hardhat configurePacketTypes --network mumbai --src 0x18BC2Be450e04EBB72A150dfa9a268F60302215c --dst-lz-chain-id 10106
//  npx hardhat configurePacketTypes --network mumbai --src 0x18BC2Be450e04EBB72A150dfa9a268F60302215c --dst-lz-chain-id 10143

//  npx hardhat configurePacketTypes --network mumbai --src 0x74FC744146cb0067AC34DF10c6e7bcc050439D37 --dst-lz-chain-id 10106
//  npx hardhat configurePacketTypes --network mumbai --src 0x74FC744146cb0067AC34DF10c6e7bcc050439D37 --dst-lz-chain-id 10143
export const configurePacketTypes__task = async (
    taskArgs: { src: string; dstLzChainId: string },
    hre: HardhatRuntimeEnvironment,
) => {
    const packetTypes = [1, 2, 770, 771, 772, 773];

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
