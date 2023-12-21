import { ethers } from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';

export const saveBlockNumber__task = async (
    // eslint-disable-next-line @typescript-eslint/ban-types
    {},
    hre: HardhatRuntimeEnvironment,
) => {
    console.log('Retrieving latest block');
    const latestBlock = await hre.ethers.provider.getBlock('latest');
    console.log('Saving latest block');
    const dep = hre.SDK.db.buildLocalDeployment({
        chainId: String(hre.network.config.chainId),
        contracts: [
            {
                name: 'NonContract-BlockDetails',
                address: hre.ethers.constants.AddressZero,
                meta: {
                    blockNumber: latestBlock.number,
                    nonce: latestBlock.nonce,
                    timestamp: latestBlock.timestamp,
                },
            },
        ],
    });
    hre.SDK.db.saveGlobally(dep, 'non-contracts', 'default');
    console.log('Done');
};
