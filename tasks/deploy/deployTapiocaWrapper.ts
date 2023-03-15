import { HardhatRuntimeEnvironment } from 'hardhat/types';

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
    const tx = await (
        await tapiocaWrapper.deploy(signer.address)
    ).deployTransaction.wait(3);

    console.log('[+] TapiocaWrapper deployed at', tx.contractAddress);
};
