import { EChainID } from '@tapioca-sdk/api/config';

// Name of the contract deployments to be used in the deployment scripts and saved in the deployments file
export const DEPLOYMENT_NAMES = {
    // MODULES
    TOFT_EXT_EXEC: 'TOFT_EXT_EXEC',
    TOFT_SENDER_MODULE: 'TOFT_SENDER_MODULE',
    TOFT_RECEIVER_MODULE: 'TOFT_RECEIVER_MODULE',
    TOFT_MARKET_RECEIVER_MODULE: 'TOFT_MARKET_RECEIVER_MODULE',
    TOFT_OPTIONS_RECEIVER_MODULE: 'TOFT_OPTIONS_RECEIVER_MODULE',
    TOFT_GENERIC_RECEIVER_MODULE: 'TOFT_GENERIC_RECEIVER_MODULE',
    TOFT_VAULT: 'TOFT_VAULT',
    // mTOFT
    mtWETH: 'mtWETH',
    // tOFT BB
    tWSTETH: 'tWSTETH',
    tRETH: 'tRETH',
    // tOFT SGL
    TOFT_S_DAI: 'TOFT_S_DAI',
    TOFT_GLP: 'TOFT_GLP',
};

type TPostLbp = {
    [key in EChainID]?: { WETH: string; wstETH: string; reth: string };
};

const POST_LBP: TPostLbp = {
    [EChainID.ARBITRUM]: {
        WETH: '0x82aF49447D8a07e3bd95BD0d56f35241523fBab1',
        wstETH: '0x5979D7b546E38E414F7E9822514be443A4800529',
        reth: '',
    },
    [EChainID.MAINNET]: {
        WETH: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
        wstETH: '0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0',
        reth: '0xae78736Cd615f374D3085123A210448E74Fc6393',
    },
    [EChainID.ARBITRUM_SEPOLIA]: {
        WETH: '0x2EAe4fbc552fE35C1D3Df2B546032409bb0E431E',
        wstETH: '',
        reth: '',
    },
    [EChainID.SEPOLIA]: {
        WETH: '0xD8a79b479b0c47675E3882A1DAA494b6775CE227',
        wstETH: '',
        reth: '',
    },
    [EChainID.OPTIMISM_SEPOLIA]: {
        WETH: '0x4fB538Ed1a085200bD08F66083B72c0bfEb29112',
        wstETH: '',
        reth: '',
    },
};
POST_LBP['31337' as EChainID] = POST_LBP[EChainID.ARBITRUM]; // Copy from Arbitrum

type TMisc = {
    [key in EChainID]?: {
        STARGATE_ROUTER: string;
    };
};
const MISC: TMisc = {
    [EChainID.MAINNET]: {
        STARGATE_ROUTER: '0x8731d54E9D02c286767d56ac03e8037C07e01e98',
    },
    [EChainID.ARBITRUM]: {
        STARGATE_ROUTER: '0x53Bf833A5d6c4ddA888F69c22C88C9f356a41614',
    },
    [EChainID.ARBITRUM_SEPOLIA]: {
        STARGATE_ROUTER: '0x2a4C2F5ffB0E0F2dcB3f9EBBd442B8F77ECDB9Cc',
    },
    [EChainID.SEPOLIA]: {
        STARGATE_ROUTER: '0x2836045A50744FB50D3d04a9C8D18aD7B5012102',
    },
};

export const DEPLOY_CONFIG = {
    POST_LBP,
    MISC,
};
