import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import { typechain } from 'tapioca-sdk';

export const loadVM = async (
    hre: HardhatRuntimeEnvironment,
    tag: string,
    debugMode = false,
) => {
    const signer = (await hre.ethers.getSigners())[0];
    const chainInfo = hre.SDK.utils.getChainBy(
        'chainId',
        await hre.getChainId(),
    );
    const multicallAddress =
        hre.SDK.config.MULTICALL_ADDRESSES[chainInfo?.chainId];
    if (!multicallAddress) {
        throw '[-] Multicall not deployed';
    }

    const VM = new hre.SDK.DeployerVM(hre, {
        // Change this if you get bytecode size error / gas required exceeds allowance (550000000)/ anything related to bytecode size
        // Could be different by network/RPC provider
        bytecodeSizeLimit: 100_000,
        multicall: typechain.Multicall.Multicall3__factory.connect(
            multicallAddress,
            signer,
        ),
        debugMode,
        tag,
    });
    return VM;
};
