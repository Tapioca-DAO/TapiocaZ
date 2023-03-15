import { EChainID } from 'tapioca-sdk/dist/api/config';

// TODO - add all chains (Eth, Arb, OP, and their testnets), double check the values
export const STARGATE_ROUTERS: {
    [key in EChainID]?: {
        stargateChainId: string;
        router: string;
        routerETH: string;
    };
} = {
    // Mainnet
    [EChainID.MAINNET]: {
        stargateChainId: '101',
        routerETH: '0x150f94b44927f078737562f0fcf3c95c01cc2376',
        router: '0x8731d54E9D02c286767d56ac03e8037C07e01e98',
    },
    // Testnet
    [EChainID.GOERLI]: {
        stargateChainId: '10121',
        routerETH: '0xdb19Ad528F4649692B92586828346beF9e4a3532',
        router: '0x7612aE2a34E5A363E137De748801FB4c86499152',
    },
    [EChainID.ARBITRUM_GOERLI]: {
        stargateChainId: '10143',
        routerETH: '0x7612aE2a34E5A363E137De748801FB4c86499152',
        router: '0xb850873f4c993Ac2405A1AdD71F6ca5D4d4d6b4f',
    },
};
