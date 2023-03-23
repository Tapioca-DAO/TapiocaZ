import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { typechain } from 'tapioca-sdk';
import { loadVM } from '../utils';

export const deployTapiocaWrapper__task = async (
    taskArgs: { overwrite?: boolean },
    hre: HardhatRuntimeEnvironment,
) => {
    console.log('[+] Deploying TapiocaWrapper...');
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');

    const { overwrite } = taskArgs;

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

    const deployerVM = await loadVM(hre, tag);

    deployerVM.add({
        contract: tapiocaWrapper,
        args: [signer.address],
        deploymentName: 'TapiocaWrapper',
    });
    await deployerVM.execute(3);
    deployerVM.save();
    await deployerVM.verify();
};
