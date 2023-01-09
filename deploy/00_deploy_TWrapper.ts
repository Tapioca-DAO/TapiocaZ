import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { TContract } from 'tapioca-sdk/dist/shared';
import SDK from 'tapioca-sdk';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = await hre.getChainId();
    const contracts: TContract[] = [];

    console.log('\n Deploying TapiocaWrapper...');
    await deploy('TapiocaWrapper', {
        from: deployer,
        log: true,
    });
    await verify(hre, 'TapiocaWrapper', []);
    const deployedAt = await deployments.get('TapiocaWrapper');
    console.log(
        `Done. Deployed TapiocaWrapper on ${deployedAt.address} with no arguments`,
    );
    contracts.push({
        name: 'TapiocaWrapper',
        address: deployedAt.address,
        meta: {},
    });
    await updateDeployments(contracts, chainId);
};

const verify = async (
    hre: HardhatRuntimeEnvironment,
    artifact: string,
    args: any[],
) => {
    const { deployments } = hre;

    const deployed = await deployments.get(artifact);
    console.log(`[+] Verifying ${artifact}`);
    try {
        await hre.run('verify', {
            address: deployed.address,
            constructorArgsParams: args,
        });
        console.log('[+] Verified');
    } catch (err: any) {
        console.log(
            `[-] failed to verify ${artifact}; error: ${err.message}\n`,
        );
    }
};

const updateDeployments = async (contracts: TContract[], chainId: string) => {
    await SDK.API.utils.saveDeploymentOnDisk({
        [chainId]: contracts,
    });
};

export default func;
func.tags = ['TapiocaWrapper'];
