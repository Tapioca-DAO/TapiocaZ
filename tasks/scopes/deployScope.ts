import '@nomiclabs/hardhat-ethers';
import { scope } from 'hardhat/config';
import { TAP_TASK } from 'tapioca-sdk';
import { deployPostLbp__task } from 'tasks/deploy/1-deployPostLbp__task';
import { deployFinal__task } from 'tasks/deploy/2-deployFinal__task';

const deployScope = scope('deploys', 'Deployment tasks');

TAP_TASK(
    deployScope
        .task(
            'postLbp',
            'Will deploy Balancer, mtETH, tWSTETH, and tRETH.',
            deployPostLbp__task,
        )
        .addParam('sdaiHostChainName', 'Host chain name of the sDai.'),
);

TAP_TASK(
    deployScope
        .task(
            'final',
            'Will deploy SGL sDAI market OFT on Arb + Eth and link them.',
            deployFinal__task,
        )
        .addParam(
            'sdaiMarketChainName',
            'Host chain name of the SGL sDai market.',
            'ethereum',
        ),
);
