import '@nomiclabs/hardhat-ethers';
import { task } from 'hardhat/config';
import { LZ_ENDPOINTS } from './scripts/constants';
import { deployTOFT } from './tasks/DeployTOFT';
import { exportSDK__task } from './tasks/exportSDK';
import { listDeploy } from './tasks/listDeploy';
import { toftSendFrom } from './tasks/TOFTsendFrom';
import { wrap } from './tasks/wrap';

function formatLZEndpoints() {
    return Object.keys(LZ_ENDPOINTS)
        .map((chainId) => {
            const { name, address, lzChainId } = LZ_ENDPOINTS[chainId];
            return `${name} (${chainId}) ${address} ${lzChainId}\n`;
        })
        .reduce((p, c) => p + c, '');
}

task('accounts', 'Prints the list of accounts', async (taskArgs, hre) => {
    const accounts = await hre.ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

task(
    'listDeploy',
    'List the deployment addresses of the selected network',
    listDeploy,
);

task(
    'deployTOFT',
    'Deploy a TOFT off an ERC20 address on the current chain',
    deployTOFT,
)
    .addParam('erc20', 'The ERC20 address to wrap')
    .addParam('lzChainId', `The main chain ID ()\n${formatLZEndpoints()}`);

task(
    'sendFrom',
    'Execute a sendFrom transaction from the current account',
    toftSendFrom,
)
    .addParam('toft', 'The TOFT contract')
    .addParam('to', 'Where to send the tokens')
    .addParam('amount', 'The amount of tokens to send');

task('wrap', 'Approve and wrap an ERC20 to its TOFT', wrap)
    .addParam('toft', 'The TOFT contract')
    .addParam('amount', 'The amount of ERC20 to wrap');

task(
    'exportSDK',
    'Generate and export the typings and/or addresses for the SDK. May deploy contracts.',
    exportSDK__task,
).addFlag('mainnet', 'Using the current chain ID deployments.');
