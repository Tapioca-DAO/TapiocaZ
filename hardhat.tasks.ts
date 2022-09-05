import '@nomiclabs/hardhat-ethers';
import { execSync } from 'node:child_process';
import { task } from 'hardhat/config';
import { deployTOFT } from './tasks/DeployTOFT';
import { exportSDK__task } from './tasks/exportSDK';
import { listDeploy } from './tasks/listDeploy';
import { toftSendFrom } from './tasks/TOFTsendFrom';
import { wrap } from './tasks/wrap';
import { API } from 'tapioca-sdk';

function formatLZEndpoints() {
    return API.utils
        .getChainIDs()
        .map((chainId) => {
            const { name, address, lzChainId } = API.utils.getChainBy(
                'chainId',
                chainId,
            )!;
            return `${name} (${chainId}) ${address} ${lzChainId}\n`;
        })
        .reduce((p, c) => p + c, '');
}

task('build', 'Compile contracts and generate Typechain files', async () => {
    execSync(
        'npx hardhat compile --config hardhat.export.ts && npx hardhat typechain',
        { stdio: 'inherit' },
    );
});

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
    // eslint-disable-next-line quotes
    "\nDeploy a TOFT contract to the specified network. It'll also deploy it to Tapioca host chain (Optimism, chainID 10).\nA document will be created in the deployments.json file.",
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
    'Generate and export the typings and/or addresses for the SDK.',
    exportSDK__task,
);
