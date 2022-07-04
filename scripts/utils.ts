import { BytesLike } from 'ethers';
import { existsSync, readFileSync, writeFileSync } from 'fs';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import config from '../hardhat.export';

export const useNetwork = async (
    hre: HardhatRuntimeEnvironment,
    network: string,
) => {
    const pk = process.env.PRIVATE_KEY;
    if (pk === undefined) throw new Error('[-] PRIVATE_KEY not set');
    const info: any = config.networks?.[network];
    if (!info) throw new Error(`[-] Network ${network} not found`);

    const provider = new hre.ethers.providers.JsonRpcProvider(
        { url: info.url },
        { chainId: info.chainId, name: `rpc-${info.chainId}` },
    );

    return new hre.ethers.Wallet(pk, provider);
};

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
    ) => {
        let erc20name;
        let erc20symbol;
        let erc20decimal;
        if (erc20Address === ethers.constants.AddressZero) {
            erc20name = 'ETH';
            erc20symbol = 'ETH';
            erc20decimal = 18;
        } else {
            const network = Object.keys(config.networks!).find(
                (e) => config.networks?.[e]?.chainId === mainChainID,
            );
            if (network) {
                const networkSigner = await useNetwork(hre, network);
                const erc20 = (
                    await ethers.getContractAt('ERC20', erc20Address)
                ).connect(networkSigner);
                erc20name = await erc20.name();
                erc20symbol = await erc20.symbol();
                erc20decimal = await erc20.decimals();
            }
        }
        return (
            await ethers.getContractFactory(contractName)
        ).getDeployTransaction(
            lzEndpoint,
            erc20Address,
            erc20name,
            erc20symbol,
            erc20decimal,
            mainChainID,
        ).data as BytesLike;
    };

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
    [chain: string]: [
        {
            name: string;
            address: string;
        },
    ];
};

export const readTOFTDeployments = (): TDeployment => {
    return readFromJson('deployments.json');
};

export const saveTOFTDeployment = (chainId: string, contracts: TContract[]) => {
    const deployments: TDeployment = {} && readFromJson('deployments.json');

    for (const contract of contracts) {
        deployments[chainId].push({
            name: contract.name,
            address: contract.address,
        });
    }

    saveToJson(deployments, 'deployments.json', 'a');
    return deployments;
};
