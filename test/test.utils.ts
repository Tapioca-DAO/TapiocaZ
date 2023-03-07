import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { useUtils } from '../scripts/utils';

export const register = async (hre: HardhatRuntimeEnvironment) => {
    const { ethers } = hre;
    const signer = (await ethers.getSigners())[0];

    const { deployLZEndpointMock, deployTapiocaWrapper, deployYieldBoxMock } =
        useUtils(hre);

    const utils = useUtils(hre);
    return {
        signer,
        LZEndpointMock_chainID_0: await deployLZEndpointMock(0),
        LZEndpointMock_chainID_10: await deployLZEndpointMock(10),
        tapiocaWrapper_0: await deployTapiocaWrapper(),
        tapiocaWrapper_10: await deployTapiocaWrapper(),
        YieldBox_0: await deployYieldBoxMock(),
        YieldBox_10: await deployYieldBoxMock(),
        utils,
    };
};
