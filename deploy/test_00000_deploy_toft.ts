import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';
import { TContract } from 'tapioca-sdk/dist/shared';
import { verify, updateDeployments } from './utils';
import SDK from 'tapioca-sdk';

//This is just a test; For deploying an actual tOFT, please use the task
const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();
    const chainId = await hre.getChainId();
    const contracts: TContract[] = [];

    console.log('\n Deploying TapiocaOFT TEST...');
    const args = [
        '0xbfD2135BFfbb0B5378b56643c2Df8a87552Bfa23', //goerli LZ adress,
        false,
        '0x8ec7f2746d9098a627134091bc9afb4629a8642d', //erc20
        '0xCA3604D7Df34a785D20Cbe7A0Bbd0AF54E9FeF9e',
        'Test',
        'TTT',
        18,
        chainId,
    ];
    await deploy('TapiocaOFT', {
        from: deployer,
        log: true,
        args,
    });
    const argsStr = [
        '0xbfD2135BFfbb0B5378b56643c2Df8a87552Bfa23', //goerli LZ adress,
        'false',
        '0x8ec7f2746d9098a627134091bc9afb4629a8642d', //erc20
        '0xCA3604D7Df34a785D20Cbe7A0Bbd0AF54E9FeF9e',
        'Test',
        'TTT',
        '18',
        chainId,
    ];
    await verify(hre, 'TapiocaOFT', argsStr);
    const deployedAt = await deployments.get('TapiocaOFT');
    console.log(
        `Done. Deployed TapiocaOFT on ${deployedAt.address} with arguments [${args}]`,
    );
    contracts.push({
        name: 'TapiocaOFT',
        address: deployedAt.address,
        meta: { constructorArguments: args },
    });
    await updateDeployments(contracts, chainId);
};

export default func;
func.tags = ['TapiocaOFT'];
