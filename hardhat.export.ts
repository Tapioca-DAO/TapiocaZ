import * as dotenv from 'dotenv';

import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-chai-matchers';
import '@nomicfoundation/hardhat-toolbox';
import 'hardhat-deploy';
import 'hardhat-contract-sizer';
import '@primitivefi/hardhat-dodoc';

dotenv.config();

export type LzNetworkConfig = {
    networks: {
        [network: string]: any & {
            lzChainId: number;
        };
    };
};

const config: HardhatUserConfig & LzNetworkConfig = {
    solidity: {
        compilers: [
            {
                version: '0.8.15',
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 100,
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
            allowUnlimitedContractSize: true,
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
        rinkeby: {
            gasMultiplier: 2,
            url:
                process.env.RINKEBY ??
                'https://rinkeby.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161',
            chainId: 4,
            lzChainId: 10001,
            accounts:
                process.env.PRIVATE_KEY !== undefined
                    ? [process.env.PRIVATE_KEY]
                    : [],
            tags: ['testnet'],
        },
        mumbai: {
            gasMultiplier: 2,
            url: 'https://rpc-mumbai.maticvigil.com',
            chainId: 80001,
            lzChainId: 10009,
            accounts:
                process.env.PRIVATE_KEY !== undefined
                    ? [process.env.PRIVATE_KEY]
                    : [],
            tags: ['testnet'],
        },
    },
    etherscan: {
        apiKey: {
            rinkeby: process.env.RINKEBY_KEY ?? '',
            polygonMumbai: process.env.POLYGON_MUMBAI_KEY ?? '',
        },
        customChains: [],
    },
    typechain: {
        outDir: './typechain',
    },
    dodoc: {
        include: ['TapiocaWrapper', 'TapiocaOFT'],
        exclude: ['TapiocaOFTMock'],
    },
    mocha: {
        timeout: 4000000,
    },
};

export default config;
