import * as dotenv from 'dotenv';

import '@nomicfoundation/hardhat-toolbox';
import '@nomicfoundation/hardhat-chai-matchers';
import { HardhatUserConfig } from 'hardhat/config';
import 'hardhat-deploy';
import 'hardhat-contract-sizer';
import '@primitivefi/hardhat-dodoc';
import SDK from 'tapioca-sdk';
import 'hardhat-tracer';
import { HttpNetworkConfig } from 'hardhat/types';

dotenv.config();

declare global {
    // eslint-disable-next-line @typescript-eslint/no-namespace
    namespace NodeJS {
        interface ProcessEnv {
            ALCHEMY_API_KEY: string;
        }
    }
}

type TNetwork = ReturnType<
    typeof SDK.API.utils.getSupportedChains
>[number]['name'];
const supportedChains = SDK.API.utils.getSupportedChains().reduce(
    (sdkChains, chain) => ({
        ...sdkChains,
        [chain.name]: <HttpNetworkConfig>{
            accounts:
                process.env.PRIVATE_KEY !== undefined
                    ? [process.env.PRIVATE_KEY]
                    : [],
            live: true,
            url: chain.rpc.replace('<api_key>', process.env.ALCHEMY_API_KEY),
            gasMultiplier: chain.tags[0] === 'testnet' ? 2 : 1,
            chainId: Number(chain.chainId),
            tags: [...chain.tags],
        },
    }),
    {} as { [key in TNetwork]: HttpNetworkConfig },
);

const config: HardhatUserConfig & { dodoc?: any; typechain?: any } = {
    SDK: { project: SDK.API.config.TAPIOCA_PROJECTS_NAME.TapiocaZ },
    solidity: {
        compilers: [
            {
                version: '0.8.18',
                settings: {
                    viaIR: true,
                    optimizer: {
                        enabled: true,
                        runs: 6,
                    },
                },
            },
            {
                version: '0.8.19',
                settings: {
                    viaIR: true,
                    optimizer: {
                        enabled: true,
                        runs: 6,
                    },
                },
            },
        ],
    },
    namedAccounts: {
        deployer: 0,
    },
    defaultNetwork: 'hardhat',
    networks: {
        hardhat: {
            saveDeployments: false,
            forking: {
                url: supportedChains['ethereum'].url,
            },
            hardfork: 'merge',
            allowUnlimitedContractSize: true,
            gas: 10_000_000,
            accounts:
                process.env.PRIVATE_KEY !== undefined
                    ? [
                          {
                              privateKey: process.env.PRIVATE_KEY,
                              balance: '1000000000000000000000000',
                          },
                      ]
                    : [],
        },
        ...supportedChains,
    },
    etherscan: {
        apiKey: {
            sepolia: process.env.BLOCKSCAN_KEY ?? '',
            arbitrum_sepolia: process.env.ARBITRUM_SEPOLIA_KEY ?? '',
            avalancheFujiTestnet: process.env.AVALANCHE_FUJI_KEY ?? '',
            bscTestnet: process.env.BSC_KEY ?? '',
            polygonMumbai: process.env.POLYGON_MUMBAI ?? '',
            ftmTestnet: process.env.FTM_TESTNET ?? '',
        },
        customChains: [
            {
                network: 'arbitrum_sepolia',
                chainId: Number(
                    SDK.API.utils.getChainBy('name', 'arbitrum_sepolia')!
                        .chainId,
                ),
                urls: {
                    apiURL: 'https://api-sepolia.arbiscan.io/api',
                    browserURL: 'https://sepolia.arbiscan.io',
                },
            },
        ],
    },
    typechain: {
        outDir: './typechain',
    },
    gasReporter: {
        enabled: false,
    },
    dodoc: {
        runOnCompile: false,
    },
    mocha: {
        timeout: 4000000,
    },
};

export default config;
