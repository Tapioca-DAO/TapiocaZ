import '@nomiclabs/hardhat-ethers';
import { scope } from 'hardhat/config';
import { TAP_TASK } from 'tapioca-sdk';
import { deployPostLbp__task } from 'tasks/deploy/1-deployPostLbp__task';

const deployScope = scope('deploys', 'Deployment tasks');

TAP_TASK(
    deployScope.task(
        'postLbp',
        'Will deploy Balancer, mtETH, tWSTETH, and tRETH. Will also set the LzPeer for each.',
        deployPostLbp__task,
    ),
);
