import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { readTOFTDeployments } from '../scripts/utils';
import SDK from 'tapioca-sdk';

// npx hardhat batchConfigureAdapterParams --network arbitrum_goerli --wrapper '0x'
export const batchConfigureAdapterParams__task = async (
    taskArgs: { wrapper: string },
    hre: HardhatRuntimeEnvironment,
) => {
    console.log('\nRetrieving necessary data');
    const currentChainId = await hre.getChainId();

    const oftFactory = await hre.ethers.getContractFactory('TapiocaOFT');
    const wrapper = await hre.ethers.getContractAt(
        'TapiocaWrapper',
        taskArgs.wrapper,
    );
    const deployments = readTOFTDeployments();

    const oftEntriesData = SDK.API.utils.getTapiocaOftEnties(
        deployments,
        'TapiocaOFT',
        oftFactory,
    );
    const chainTransactions = oftEntriesData.filter(
        (a: { srChain: string }) => a.srChain == currentChainId,
    );

    console.log(`\nTotal transaction sets: ${chainTransactions.length}`);
    let sum = 0;
    for (let i = 0; i < chainTransactions.length; i++) {
        const crtTx = chainTransactions[i];
        await (
            await wrapper.executeTOFT(
                crtTx.srcAddress,
                crtTx.customAdaptersTx,
                true,
            )
        ).wait(2);

        for (
            let packetIndex = 0;
            packetIndex < crtTx.packetTypesTxs.length;
            packetIndex++
        ) {
            await (
                await wrapper.executeTOFT(
                    crtTx.srcAddress,
                    crtTx.packetTypesTxs[packetIndex],
                    true,
                )
            ).wait(2);
        }
        console.log(`       * executed ${i}`);
        sum += 1;
    }
    console.log(`Done. Executed ${sum} transactions`);
};
