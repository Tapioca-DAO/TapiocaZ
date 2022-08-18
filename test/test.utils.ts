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
    } = useUtils(hre);

    const utils = { Tx_deployTapiocaOFT, attachTapiocaOFT };
    return {
        signer,
        LZEndpointMock_chainID_0: await deployLZEndpointMock(0),
        LZEndpointMock_chainID_10: await deployLZEndpointMock(10),
        tapiocaWrapper: await deployTapiocaWrapper(),
        utils,
    };
};
