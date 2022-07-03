import '@nomiclabs/hardhat-ethers';
import { task } from 'hardhat/config';
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
    .addParam('erc20Address', 'The ERC20 address to wrap')
    .addOptionalParam('mainChainID', 'The main chain ID ()');
