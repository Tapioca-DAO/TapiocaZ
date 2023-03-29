import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { typechain } from 'tapioca-sdk';
import { MultisigMock__factory } from '../../typechain/utils/MultisigMock/factories';
import { STARGATE_ROUTERS } from '../constants';
import { loadVM } from '../utils';

export const transferTapiocaWrapperOwnership__task = async (
    taskArgs: { to: string; multisig: string },
    hre: HardhatRuntimeEnvironment,
) => {
    console.log(
        '[+] Transfering ownership for TapiocaWrapper from Multisig to signer...',
    );
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');

    const signer = (await hre.ethers.getSigners())[0];
    const chainId = String(hre.network.config.chainId);

    // get TapiocaWrapper deployment
    const tapiocaWrapperDeployment = hre.SDK.db.getLocalDeployment(
        chainId,
        'TapiocaWrapper',
        tag,
    );
    if (!tapiocaWrapperDeployment) {
        throw '[-] TapiocaWrapper not found';
    }

    const multisig = MultisigMock__factory.connect(taskArgs.multisig, signer);

    const transferOwnershipABI = [
        'function transferOwnership(address newOwner)',
    ];
    const iTransferOwnership = new hre.ethers.utils.Interface(
        transferOwnershipABI,
    );
    const transferOwnershipCalldata = iTransferOwnership.encodeFunctionData(
        'transferOwnership',
        [taskArgs.to],
    );

    console.log('   [+] Changing owner to: ', taskArgs.to);
    let tx = await multisig.submitTransaction(
        tapiocaWrapperDeployment.address,
        0,
        transferOwnershipCalldata,
    );
    await tx.wait(3);
    const txCount = await multisig.getTransactionCount();
    const lastTx = txCount.sub(1);
    tx = await multisig.confirmTransaction(lastTx);
    await tx.wait(3);
    tx = await multisig.executeTransaction(lastTx);
    await tx.wait(3);
    console.log('   [+] Owner changed by tx: ', tx.hash);

    console.log('\n');
};
