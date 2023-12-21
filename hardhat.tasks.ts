import '@nomiclabs/hardhat-ethers';
import { task } from 'hardhat/config';
import { wrap } from './tasks/exec/wrap';

import { deployBalancer__task } from './tasks/deploy/deployBalancer';
import { deployTapiocaWrapper__task } from './tasks/deploy/deployTapiocaWrapper';
import { deployTOFT__task } from './tasks/deploy/deployTOFT';
import { deployTOFTMinter__task } from './tasks/deploy/testnet/deployTOFTMinter';
import { setConnectedChain__task } from './tasks/exec/setConnectedChain';
import { setCluster__task } from './tasks/exec/setCluster';
import { saveBlockNumber__task } from './tasks/exec/saveBlockNumber';
import { toggleSwapEth__task } from './tasks/exec/01-balancer-toggleSwapEth';
import { emergencySaveTokens__task } from './tasks/exec/02-balancer-emergencySaveTokens';
import { initConnectedOFT__task } from './tasks/exec/03-balancer-initConnectedOFT';
import { addRebalanceAmount__task } from './tasks/exec/04-balancer-addRebalanceAmount';
import { retryRevertOnBalancer__task } from './tasks/exec/05-balancer-retryRevert';
import { instantRedeemLocalOnBalancer__task } from './tasks/exec/06-balancer-instantRedeemLocal';
import { redeemLocalOnBalancer__task } from './tasks/exec/07-balancer-redeemLocal';
import { redeemRemoteOnBalancer__task } from './tasks/exec/08-balancer-redeemRemote';
import { updateConnectedChain__task } from './tasks/exec/09-mOft-updateConnectedChain';
import { updateBalancerState__task } from './tasks/exec/10-mOft-updateBalancerState';
import { rescueEthFromOft__task } from './tasks/exec/11-oft-rescueEth';
import { setStargateRouterOnOft__task } from './tasks/exec/12-oft-setStargateRouter';

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

task('setCluster', 'Set cluster', setCluster__task)
    .addParam('toft', 'mTapiocaOFT address')
    .addParam('cluster', 'Cluster address');

task('saveBlockNumber', 'adsadasda', saveBlockNumber__task);

task(
    'toggleSwapEth',
    'Disable/Enable swap eth on balancer',
    toggleSwapEth__task,
);

task(
    'emergencySaveTokens',
    'Emergency save tokens from Balancer',
    emergencySaveTokens__task,
);

task(
    'initConnectedOFT',
    'Init a connected OFT on Balancer',
    initConnectedOFT__task,
);

task(
    'setRebalanceAmount',
    'Set rebalanceable amount to Balancer',
    addRebalanceAmount__task,
);

task(
    'retryRevertOnBalancer',
    'Retry revert on Balancer',
    retryRevertOnBalancer__task,
);

task(
    'instantRedeemLocalOnBalancer',
    'Instant redeem on Balancer',
    instantRedeemLocalOnBalancer__task,
);

task(
    'redeemLocalOnBalancer',
    'Redeem local on Balancer',
    redeemLocalOnBalancer__task,
);

task(
    'redeemRemoteOnBalancer',
    'Redeem remote on Balancer',
    redeemRemoteOnBalancer__task,
);

task(
    'updateConnectedChain',
    'Update a connected chain status for mTapiocaOFT contract',
    updateConnectedChain__task,
);

task(
    'updateBalancerState',
    'Update a balancer status for mTapiocaOFT contract',
    updateBalancerState__task,
);

task('rescueEthFromOft', 'Rescue ETH from OFT', rescueEthFromOft__task);

task(
    'setStargateRouterOnOft',
    'Rescue ETH from OFT',
    setStargateRouterOnOft__task,
);
