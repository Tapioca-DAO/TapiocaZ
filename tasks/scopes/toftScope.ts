import '@nomiclabs/hardhat-ethers';
import { glob } from 'glob';
import { scope } from 'hardhat/config';

import { updateConnectedChain__task } from '../exec/toft/09-mOft-updateConnectedChain';
import { updateBalancerState__task } from '../exec/toft/10-mOft-updateBalancerState';
import { rescueEthFromOft__task } from '../exec/toft/11-oft-rescueEth';
import { setStargateRouterOnOft__task } from '../exec/toft/12-oft-setStargateRouter';
import { setCluster__task } from '../exec/toft/13-setCluster';

const tOFTScope = scope('oft', 'TOFT & mTOFT tasks');

tOFTScope
    .task('setCluster', 'Set cluster', setCluster__task)
    .addParam('address', 'mTapiocaOFT address')
    .addParam('cluster', 'Cluster address')
    .addFlag('oft', 'true for TOFT contract; false for mTOFT contract');

tOFTScope
    .task(
        'updateConnectedChain',
        'Update a connected chain status for mTapiocaOFT contract',
        updateConnectedChain__task,
    )
    .addParam('address', 'mTOFT address');

tOFTScope
    .task(
        'updateBalancerState',
        'Update a balancer status for mTapiocaOFT contract',
        updateBalancerState__task,
    )
    .addParam('address', 'mTOFT address');

tOFTScope
    .task('rescueEthFromOft', 'Rescue ETH from OFT', rescueEthFromOft__task)
    .addParam('address', 'mTOFT address')
    .addFlag('oft', 'true for TOFT contract; false for mTOFT contract');

tOFTScope
    .task(
        'setStargateRouterOnOft',
        'Rescue ETH from OFT',
        setStargateRouterOnOft__task,
    )
    .addParam('address', 'mTOFT address');
