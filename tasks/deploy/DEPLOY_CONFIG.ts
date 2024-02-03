import { EChainID } from '@tapioca-sdk/api/config';

export const STARGATE_ROUTER = {
    [EChainID.ARBITRUM_SEPOLIA]: '0x2a4C2F5ffB0E0F2dcB3f9EBBd442B8F77ECDB9Cc',
    [EChainID.SEPOLIA]: '0x2836045A50744FB50D3d04a9C8D18aD7B5012102',
};
/*
 @dev - deploy HOST_TOKENS first on all chains!
**/
export const CHAIN_TOFTS = {
    [EChainID.ARBITRUM_SEPOLIA]: {
        // tokens to deploy for with `[EChainID.ARBITRUM_SEPOLIA]` as the host chain
        HOST_TOKENS: [
            //TODO: use tokens
            '0x0',
            '0x1',
            '0x2',
        ],
        // tokens to deploy for with other chains as the host
        CONNECTED_TOKENS: {
            [EChainID.SEPOLIA]: ['0x1', '0x2'],
        },
    },
};
