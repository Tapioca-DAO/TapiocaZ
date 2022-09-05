import deploymentJSON from '../deployments.json';

export const DEPLOYMENTS_PATH = 'deployments.json';
export const DEPLOYMENTS_FILE = deploymentJSON;

// Whitelisted addresses of ERC20 contracts. Per LZ chain id.
export const VALID_ADDRESSES: any = {
    '10001': {
        '0xaECE4415b0464e04a96F300570950e9Cc2956341': 'erc20TEST0',
    },
};
