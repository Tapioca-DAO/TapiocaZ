import '@nomiclabs/hardhat-ethers';
import { execSync } from 'node:child_process';
import { task } from 'hardhat/config';
import { deployTOFT__task } from './tasks/deployTOFT';
import { exportSDK__task } from './tasks/exportSDK';
import { listDeploy__task } from './tasks/listDeploy';
import { toftSendFrom } from './tasks/TOFTsendFrom';
import { wrap } from './tasks/wrap';
import { setTrustedRemote__task } from './tasks/setTrustedRemote';
import { configurePacketTypes__task } from './tasks/configurePacketTypes';
import SDK from 'tapioca-sdk';

function formatLZEndpoints() {
    return SDK.API.utils
        .getChainIDs()
        .map((chainId: any) => {
            const { name } = SDK.API.utils.getChainBy('chainId', chainId)!;
            return `${name} - (${chainId})\n`;
        })
        .reduce((p: any, c: any) => p + c, '');
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
    listDeploy__task,
);

task(
    'deployTOFT',
    // eslint-disable-next-line quotes
    "\nDeploy a TOFT contract to the specified network. It'll also deploy it to Tapioca host chain (Optimism, chainID 10).\nA document will be created in the deployments.json file.",
    deployTOFT__task,
)
    .addParam('erc20', 'The ERC20 address to wrap')
    .addParam('yieldBox', 'The YieldBox address')
    .addParam('salt', 'The salt used CREATE2 deployment')
    .addParam('hostChainName', `The main chain ID ()\n${formatLZEndpoints()}`);

task(
    'sendFrom',
    'Execute a sendFrom transaction from the current account',
    toftSendFrom,
)
    .addParam('toft', 'The TOFT contract')
    .addParam('to', "Where to send the tokens, can be 'host' or 'linked'")
    .addParam('amount', 'The amount of tokens to send');

task('wrap', 'Approve and wrap an ERC20 to its TOFT', wrap)
    .addParam('toft', 'The TOFT contract')
    .addParam('amount', 'The amount of ERC20 to wrap');

task(
    'exportSDK',
    'Generate and export the typings and/or addresses for the SDK.',
    exportSDK__task,
);

task(
    'setTrustedRemote',
    'Calls setTrustedRemote on tOFT contract',
    setTrustedRemote__task,
)
    .addParam('chain', 'LZ destination chain id for trusted remotes')
    .addParam('dst', 'tOFT destination address')
    .addParam('src', 'tOFT source address');

task(
    'configurePacketTypes',
    'Cofigures min destination gas and the usage of custom adapters',
    configurePacketTypes__task,
)
    .addParam('dstLzChainId', 'LZ destination chain id for trusted remotes')
    .addParam('src', 'tOFT address');
