import hre from 'hardhat';

const deployERC20 = async () => {
    const test0 = await (
        await hre.ethers.getContractFactory('ERC20Mock')
    ).deploy('erc20TEST0', 'TEST0');
    await test0.deployed();
    console.log('\n', await hre.getChainId(), test0.address);
    console.log('10e6 free mint for deployer ');

    await (
        await test0.mint(
            (
                await hre.ethers.getSigners()
            )[0].address,
            hre.ethers.utils.parseEther((10e6).toString()),
        )
    ).wait();
};

deployERC20()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.kill(1);
    });
