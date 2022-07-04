import { BytesLike } from 'ethers';
import { existsSync, readFileSync, writeFileSync } from 'fs';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
export const useUtils = (hre: HardhatRuntimeEnvironment, isMock?: boolean) => {
    const { ethers } = hre;

    // DEPLOYMENTS
    const deployLZEndpointMock = async (chainId: number) =>
        await (
            await (
                await ethers.getContractFactory('LZEndpointMock')
            ).deploy(chainId)
        ).deployed();

    const deployTapiocaWrapper = async () =>
        await (
            await (await ethers.getContractFactory('TapiocaWrapper')).deploy()
        ).deployed();

    // UTILS
    const contractName = isMock ? 'TapiocaOFTMock' : 'TapiocaOFT';
    const Tx_deployTapiocaOFT = async (
        lzEndpoint: string,
        erc20Address: string,
        mainChainID: number,
    ) =>
        (await ethers.getContractFactory(contractName)).getDeployTransaction(
            lzEndpoint,
            erc20Address,
            mainChainID,
        ).data as BytesLike;

    const attachTapiocaOFT = async (address: string) =>
        await ethers.getContractAt(contractName, address);

    return {
        deployLZEndpointMock,
        deployTapiocaWrapper,
        Tx_deployTapiocaOFT,
        attachTapiocaOFT,
    };
};

export const saveToJson = (data: any, filename: string, flag: 'a' | 'w') => {
    const json = JSON.stringify(data, null, 2);
    writeFileSync(filename, json, { flag });
};

export const readFromJson = (filename: string) => {
    if (existsSync(filename)) {
        const json = readFileSync(filename, 'utf8');
        return JSON.parse(json);
    }
    return {};
};

export type TContract = {
    name: string;
    address: string;
};

export type TDeployment = {
    [chain: string]: {
        [name: string]: string;
    };
};

export const saveTOFTDeployment = (chainId: string, contracts: TContract[]) => {
    const deployments: TDeployment = {} && readFromJson('deployments.json');

    for (const contract of contracts) {
        deployments[chainId] = {
            [contract.name]: contract.address,
        };
    }

    saveToJson(deployments, 'deployments.json', 'a');
};
