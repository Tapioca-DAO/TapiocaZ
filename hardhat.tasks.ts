import '@nomiclabs/hardhat-ethers';
import { task } from 'hardhat/config';
import { LZ_ENDPOINT } from './scripts/constants';
import { deployTOFT } from './tasks/DeployTOFT';

task('accounts', 'Prints the list of accounts', async (taskArgs, hre) => {
    const accounts = await hre.ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

task(
    'deployTOFT',
    'Deploy a TOFT off an ERC20 address on the current chain',
    deployTOFT,
)
    .addParam('erc20', 'The ERC20 address to wrap')
    .addParam('chainid', `The main chain ID ()\n${formatLZEndpoints()}`);

function formatLZEndpoints() {
    return Object.keys(LZ_ENDPOINT)
        .map((chainId) => {
            const { name, address, lzChainId } = LZ_ENDPOINT[chainId];
            return `${name} (${chainId}) ${address} ${lzChainId}\n`;
        })
        .reduce((p, c) => p + c, '');
}
