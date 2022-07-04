import hre, { ethers } from 'hardhat';

const deployERC20 = async () => {
    const test0 = await (
        await hre.ethers.getContractFactory('ERC20')
    ).deploy('erc20TEST0', 'TEST0');
    console.log('\n', await hre.getChainId(), test0.address);
};

deployERC20()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.kill(1);
    });
