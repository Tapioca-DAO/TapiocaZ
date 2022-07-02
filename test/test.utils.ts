import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { useUtils } from '../scripts/utils';

export const register = async (hre: HardhatRuntimeEnvironment) => {
    const { ethers } = hre;
    const signer = (await ethers.getSigners())[0];

    const {
        deployLZEndpointMock,
        deployTapiocaWrapper,
        Tx_deployTapiocaOFT,
        attachTapiocaOFT,
    } = useUtils(hre, true);

    const utils = { Tx_deployTapiocaOFT, attachTapiocaOFT };
    return {
        signer,
        LZEndpointMock0: await deployLZEndpointMock(0),
        LZEndpointMock1: await deployLZEndpointMock(1),
        tapiocaWrapper: await deployTapiocaWrapper(),
        utils,
    };
};
