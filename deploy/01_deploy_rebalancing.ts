import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { TContract } from 'tapioca-sdk/dist/shared';
import { verify, updateDeployments, constants } from './utils';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = await hre.getChainId();
    const contracts: TContract[] = [];

    const routerEth = '0x150f94b44927f078737562f0fcf3c95c01cc2376';
    const router = '0x8731d54e9d02c286767d56ac03e8037c07e01e98';

    console.log('\n Deploying Balancer...');
    const args = [constants[chainId].routerETH, constants[chainId].router];
    await deploy('Balancer', {
        from: deployer,
        log: true,
        args,
    });
    await verify(hre, 'Balancer', args);
    const deployedAt = await deployments.get('Balancer');
    console.log(
        `Done. Deployed Balancer on ${deployedAt.address} with args [${args}]`,
    );
    contracts.push({
        name: 'Balancer',
        address: deployedAt.address,
        meta: {},
    });
    await updateDeployments(contracts, chainId);
};

export default func;
func.tags = ['Balancer'];
