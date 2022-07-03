import { HardhatRuntimeEnvironment } from 'hardhat/types';
import { DeployFunction } from 'hardhat-deploy/types';

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
    const { deployments, getNamedAccounts } = hre;
    const { deploy } = deployments;
    const { deployer } = await getNamedAccounts();

    await deploy('TapiocaWrapper', {
        from: deployer,
        log: true,
    });

    if (hre.network.live || hre.network.tags['rinkeby']) {
        try {
            const twrapper = await deployments.get('TapiocaWrapper');
            await hre.run('verify', {
                address: twrapper.address,
            });
        } catch (err) {
            console.log(err);
        }
    }
};
export default func;
func.tags = ['TapiocaWrapper'];
