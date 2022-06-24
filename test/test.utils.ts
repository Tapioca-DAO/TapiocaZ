import { HardhatRuntimeEnvironment } from 'hardhat/types';

export const register = async (hre: HardhatRuntimeEnvironment) => {
    const { ethers } = hre;
    const signer = (await ethers.getSigners())[0];

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
    const Tx_deployTapiocaOFT = async (
        lzEndpoint: string,
        erc20Address: string,
        mainChainID: number,
    ) =>
        (
            await ethers.getContractFactory('TapiocaOFTMock')
        ).getDeployTransaction(lzEndpoint, erc20Address, mainChainID).data;

    const attachTapiocaOFT = async (address: string) =>
        await ethers.getContractAt('TapiocaOFTMock', address);

    const utils = {
        Tx_deployTapiocaOFT,
        attachTapiocaOFT,
    };

    return {
        signer,
        LZEndpointMock0: await deployLZEndpointMock(0),
        LZEndpointMock1: await deployLZEndpointMock(1),
        tapiocaWrapper: await deployTapiocaWrapper(),
        utils,
    };
};
