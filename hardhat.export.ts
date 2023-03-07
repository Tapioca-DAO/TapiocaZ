import * as dotenv from 'dotenv';

import '@nomicfoundation/hardhat-toolbox';
import '@nomicfoundation/hardhat-chai-matchers';
import { HardhatUserConfig } from 'hardhat/config';
import 'hardhat-deploy';
import 'hardhat-contract-sizer';
import '@primitivefi/hardhat-dodoc';
import SDK from 'tapioca-sdk';
import 'hardhat-tracer';

dotenv.config();

const supportedChains: { [key: string]: HttpNetworkConfig } = SDK.API.utils
    .getSupportedChains()
    .reduce(
        (sdkChains, chain) => ({
            ...sdkChains,
            [chain.name]: <HttpNetworkConfig>{
                accounts:
                    process.env.PRIVATE_KEY !== undefined
                        ? [process.env.PRIVATE_KEY]
                        : [],
                live: true,
                url: chain.rpc.replace('<api_key>', process.env.ALCHEMY_KEY!),
                gasMultiplier: chain.tags.includes('testnet') ? 2 : 1,
                chainId: Number(chain.chainId),
            },
        }),
        {},
    );

const config: HardhatUserConfig & { dodoc?: any; typechain?: any } = {
    solidity: {
        compilers: [
            {
                version: '0.8.18',
                settings: {
                    viaIR: true,
                    optimizer: {
                        enabled: true,
                        runs: 200,

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
        //testnets
        goerli: supportedChains['goerli'],
        bnb_testnet: supportedChains['bnb_testnet'],
        fuji_avalanche: supportedChains['fuji_avalanche'],
        mumbai: supportedChains['mumbai'],
        fantom_testnet: supportedChains['fantom_testnet'],
        arbitrum_goerli: supportedChains['arbitrum_goerli'],
        optimism_goerli: supportedChains['optimism_goerli'],
        harmony_testnet: supportedChains['harmony_testnet'],

        //mainnets
        ethereum: supportedChains['ethereum'],
        bnb: supportedChains['bnb'],
        avalanche: supportedChains['avalanche'],
        matic: supportedChains['polygon'],
        arbitrum: supportedChains['arbitrum'],
        optimism: supportedChains['optimism'],
        fantom: supportedChains['fantom'],
        harmony: supportedChains['harmony'],
    },
    etherscan: {
        apiKey: process.env.ETHERSCAN_KEY,
        customChains: [],
    },
    typechain: {
        outDir: './typechain',
    },
    gasReporter: {
        enabled: false,
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
