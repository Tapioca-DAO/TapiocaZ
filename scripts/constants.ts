export const OPTIMISM_CHAIN_ID = 10;

export type TLZ_Endpoint = {
    [chainId: string]: {
        name: string;
        address: string;
        lzChainId: string;
    };
};

export const LZ_ENDPOINTS: TLZ_Endpoint = {
    '4': {
        name: 'rinkeby',
        address: '0x79a63d6d8BBD5c6dfc774dA79bCcD948EAcb53FA',
        lzChainId: '10001',
    },
    '80001': {
        name: 'mumbai',
        address: '0xf69186dfBa60DdB133E91E9A4B5673624293d8F8',
        lzChainId: '10009',
    },
};

// Whitelisted addresses of an ERC20 contract, used for hh tasks
export const VALID_ADDRESSES: any = {
    '10001': {
        '0x552663741587C3331edc9F32b10fEC2882D573f2': 'erc20TEST0',
    },
};
