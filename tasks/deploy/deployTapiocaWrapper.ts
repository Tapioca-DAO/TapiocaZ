import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { typechain } from 'tapioca-sdk';

export const deployTapiocaWrapper__task = async (
    taskArgs: { overwrite?: boolean; tag?: string },
    hre: HardhatRuntimeEnvironment,
) => {
    console.log('[+] Deploying TapiocaWrapper...');

    const { overwrite, tag } = taskArgs;

    const signer = (await hre.ethers.getSigners())[0];
    const chainId = String(hre.network.config.chainId);

    // Check if already deployed
    const prevDeployment = hre.SDK.db.getLocalDeployment(
        chainId,
        'TapiocaWrapper',
        tag,
    );
    if (prevDeployment && !overwrite) {
        console.log(
            `[-] TapiocaWrapper already deployed on ${hre.network.name} at ${prevDeployment.address}`,
        );
        return;
    }

    const tapiocaWrapper = await hre.ethers.getContractFactory(
        'TapiocaWrapper',
    );

    const deployerVM = new hre.SDK.DeployerVM(hre, {
        bytecodeSizeLimit: 90_000,
        multicall: typechain.Multicall.Multicall3__factory.connect(
            hre.SDK.config.MULTICALL_ADDRESS,
            hre.ethers.provider,
        ),
        tag,
    });

    deployerVM.add({
        contract: tapiocaWrapper,
        args: [signer.address],
        deploymentName: 'TapiocaWrapper',
    });
    await deployerVM.execute(3);
    deployerVM.save();
    await deployerVM.verify();
};
