import '@nomiclabs/hardhat-ethers';
import { task } from 'hardhat/config';
import { wrap } from './tasks/exec/wrap';

import { deployBalancer__task } from './tasks/deploy/deployBalancer';
import { deployTapiocaWrapper__task } from './tasks/deploy/deployTapiocaWrapper';
import { deployTOFT__task } from './tasks/deploy/deployTOFT';
import { deployTOFTMinter__task } from './tasks/deploy/testnet/deployTOFTMinter';
import { setConnectedChain__task } from './tasks/exec/setConnectedChain';

task(
    'deployTapiocaWrapper',
    'Deploy the TapiocaWrapper',
    deployTapiocaWrapper__task,
).addFlag('overwrite', 'If the deployment should be overwritten');

task(
    'deployBalancer',
    'Deploy a mTOFT Balancer contract',
    deployBalancer__task,
).addFlag('overwrite', 'If the deployment should be overwritten');

task('deployTOFT', 'Deploy a TOFT', deployTOFT__task)
    .addOptionalParam(
        'throughMultisig',
        'If true, deploy through the Multisig contract',
    )
    .addOptionalParam('overrideOptions', 'Override options')
    .addFlag('isNative', 'If the TOFT should support the gas token')
    .addFlag('isMerged', 'If the TOFT should be a rebalanceable mTOFT');

task('wrap', 'Approve and wrap an ERC20 to its TOFT', wrap)
    .addParam('toft', 'The TOFT contract')
    .addParam('amount', 'The amount of ERC20 to wrap');

task(
    'deployTOFTMinter',
    'Deploy the TOFTMinter',
    deployTOFTMinter__task,
).addFlag('overwrite', 'If the deployment should be overwritten');

task('setConnectedChain', 'Update set connected chain', setConnectedChain__task)
    .addParam('toft', 'mTapiocaOFT address')
    .addParam('chain', 'Block chain id')
    .addParam('status', 'true/false');
