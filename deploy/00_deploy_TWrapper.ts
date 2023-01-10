import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { TContract } from 'tapioca-sdk/dist/shared';
import { verify, updateDeployments } from './utils';
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

export default func;
func.tags = ['TapiocaWrapper'];
