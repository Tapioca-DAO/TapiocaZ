import '@nomiclabs/hardhat-ethers';
import { glob } from 'glob';
import { scope } from 'hardhat/config';
import { deployBalancer__task } from 'tasks/deploy/deployBalancer';
import { deployTOFT__task } from 'tasks/deploy/deployTOFT';

const deployScope = scope('oft', 'TOFT & mTOFT tasks');

deployScope
    .task(
        'deployBalancer',
        'Deploy a mTOFT Balancer contract',
        deployBalancer__task,
    )
    .addFlag('overwrite', 'If the deployment should be overwritten');

deployScope
    .task('deployTOFT', 'Deploy a TOFT', deployTOFT__task)
    .addOptionalParam('tag', 'Deployment tag')
    .addFlag('onHost', 'Deploy for host tokens')
    .addFlag('overrideOptions', 'Override options');
