// TODO fixme use the SDK EChainID
enum EChainID {
    // Mainnets
    MAINNET = '1',
    BSC = '56',
    AVALANCHE = '43114',
    POLYGON = '137',
    FANTOM = '250',
    ARBITRUM = '42161',
    OPTIMISM = '10',
    HARMONY = '1666600000',
    // Testnets
    GOERLI = '5',
    BSC_TESTNET = '97',
    FUJI_AVALANCHE = '43113',
    MUMBAI_POLYGON = '80001',
    FANTOM_TESTNET = '4002',
    ARBITRUM_GOERLI = '421613',
    OPTIMISM_GOERLI = '420',
    HARMONY_TESTNET = '1666700000',
}

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
    [EChainID.ARBITRUM]: {
        stargateChainId: '110',
        routerETH: '0xbf22f0f184bCcbeA268dF387a49fF5238dD23E40',
        router: '0x53Bf833A5d6c4ddA888F69c22C88C9f356a41614',
    },
    [EChainID.BSC]: {
        stargateChainId: '102',
        routerETH: '0x4a364f8c717cAAD9A442737Eb7b8A55cc6cf18D8',
        router: '0x4a364f8c717cAAD9A442737Eb7b8A55cc6cf18D8',
    },
    [EChainID.AVALANCHE]: {
        stargateChainId: '106',
        routerETH: '0x45A01E4e04F14f7A4a6702c74187c5F6222033cd',
        router: '0x45A01E4e04F14f7A4a6702c74187c5F6222033cd',
    },
    [EChainID.POLYGON]: {
        stargateChainId: '109',
        routerETH: '0x45A01E4e04F14f7A4a6702c74187c5F6222033cd',
        router: '0x45A01E4e04F14f7A4a6702c74187c5F6222033cd',
    },
    [EChainID.OPTIMISM]: {
        stargateChainId: '111',
        routerETH: '0xB49c4e680174E331CB0A7fF3Ab58afC9738d5F8b',
        router: '0xB0D502E938ed5f4df2E681fE6E419ff29631d62b',
    },
    [EChainID.FANTOM]: {
        stargateChainId: '112',
        routerETH: '0xAf5191B0De278C7286d6C7CC6ab6BB8A73bA2Cd6',
        router: '0xAf5191B0De278C7286d6C7CC6ab6BB8A73bA2Cd6',
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
    [EChainID.FUJI_AVALANCHE]: {
        stargateChainId: '10106',
        routerETH: '0x7612aE2a34E5A363E137De748801FB4c86499152',
        router: '0xb850873f4c993Ac2405A1AdD71F6ca5D4d4d6b4f',
    },
    [EChainID.MUMBAI_POLYGON]: {
        stargateChainId: '10109',
        routerETH: '0x7612aE2a34E5A363E137De748801FB4c86499152',
        router: '0xb850873f4c993Ac2405A1AdD71F6ca5D4d4d6b4f',
    },
};
