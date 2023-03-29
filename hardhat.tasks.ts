import '@nomiclabs/hardhat-ethers';
import { task } from 'hardhat/config';
import { wrap } from './tasks/wrap';

import { deployBalancer__task } from './tasks/deploy/deployBalancer';
import { deployTapiocaWrapper__task } from './tasks/deploy/deployTapiocaWrapper';
import { deployTOFT__task } from './tasks/deploy/deployTOFT';
import { transferTapiocaWrapperOwnership__task } from './tasks/exec/transferTapiocaWrapperOwnership';

task(
    'deployTapiocaWrapper',
    'Deploy the TapiocaWrapper',
    deployTapiocaWrapper__task,
).addFlag('overwrite', 'If the deployment should be overwritten');

task(
    'deployBalancer',
    'Deploy a mTOFT Balancer contract',
    deployBalancer__task,
);

task('deployTOFT', 'Deploy a TOFT', deployTOFT__task)
    .addFlag('isNative', 'If the TOFT should support the gas token')
    .addFlag('isMerged', 'If the TOFT should be a rebalanceable mTOFT');

task('wrap', 'Approve and wrap an ERC20 to its TOFT', wrap)
    .addParam('toft', 'The TOFT contract')
    .addParam('amount', 'The amount of ERC20 to wrap');

task(
    'transferTapiocaWrapperOwnership',
    'Transfer ownership of TapiocaWrapper',
    transferTapiocaWrapperOwnership__task,
)
    .addParam('multisig', 'Current multisig owner')
    .addParam('to', 'The new owner');
