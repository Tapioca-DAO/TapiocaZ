import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import { typechain } from 'tapioca-sdk';

export const loadVM = async (
    hre: HardhatRuntimeEnvironment,
    tag: string,
    debugMode = false,
) => {
    const VM = new hre.SDK.DeployerVM(hre, {
        // Change this if you get bytecode size error / gas required exceeds allowance (550000000)/ anything related to bytecode size
        // Could be different by network/RPC provider
        bytecodeSizeLimit: 100_000,
        debugMode,
        tag,
    });
    return VM;
};
