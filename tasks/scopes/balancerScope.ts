import '@nomiclabs/hardhat-ethers';
import { glob } from 'glob';
import { scope } from 'hardhat/config';

import { toggleSwapEth__task } from '../exec/balancer/01-balancer-toggleSwapEth';
import { emergencySaveTokens__task } from '../exec/balancer/02-balancer-emergencySaveTokens';
import { initConnectedOFT__task } from '../exec/balancer/03-balancer-initConnectedOFT';
import { addRebalanceAmount__task } from '../exec/balancer/04-balancer-addRebalanceAmount';
import { retryRevertOnBalancer__task } from '../exec/balancer/05-balancer-retryRevert';
import { instantRedeemLocalOnBalancer__task } from '../exec/balancer/06-balancer-instantRedeemLocal';
import { redeemLocalOnBalancer__task } from '../exec/balancer/07-balancer-redeemLocal';
import { redeemRemoteOnBalancer__task } from '../exec/balancer/08-balancer-redeemRemote';

const balancerScope = scope('balancer', 'Balancer.sol tasks');

balancerScope.task(
    'toggleSwapEth',
    'Disable/Enable swap eth on balancer',
    toggleSwapEth__task,
);

balancerScope.task(
    'emergencySaveTokens',
    'Emergency save tokens from Balancer',
    emergencySaveTokens__task,
);

balancerScope.task(
    'initConnectedOFT',
    'Init a connected OFT on Balancer',
    initConnectedOFT__task,
);

balancerScope.task(
    'setRebalanceAmount',
    'Set rebalanceable amount to Balancer',
    addRebalanceAmount__task,
);

balancerScope.task(
    'retryRevertOnBalancer',
    'Retry revert on Balancer',
    retryRevertOnBalancer__task,
);

balancerScope.task(
    'instantRedeemLocalOnBalancer',
    'Instant redeem on Balancer',
    instantRedeemLocalOnBalancer__task,
);

balancerScope.task(
    'redeemLocalOnBalancer',
    'Redeem local on Balancer',
    redeemLocalOnBalancer__task,
);

balancerScope.task(
    'redeemRemoteOnBalancer',
    'Redeem remote on Balancer',
    redeemRemoteOnBalancer__task,
);
