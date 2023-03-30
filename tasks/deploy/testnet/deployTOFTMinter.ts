import { HardhatRuntimeEnvironment } from 'hardhat/types';
import inquirer from 'inquirer';
import { TOFTMinter } from '../../../typechain';

export const askForChains = async (hre: HardhatRuntimeEnvironment) => {
    const supportedChains = hre.SDK.utils.getSupportedChains();
    const choices = supportedChains.map((e) => e.name);

    const { chains }: { chains: typeof choices } = await inquirer.prompt({
        type: 'checkbox',
        name: 'chains',
        message: 'Choose chains to deploy to',
        choices,
    });

    return supportedChains.filter((e) => chains.includes(e.name));
};
export const deployTOFTMinter__task = async (
    taskArgs: { overwrite?: boolean },
    hre: HardhatRuntimeEnvironment,
) => {
    console.log('[+] Deploying TOFTMinter [+]');

    const tempConf = hre.config.SDK.project;
    hre.config.SDK.project = 'generic';

    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    const { overwrite } = taskArgs;

    const chains = await askForChains(hre);

    for (const chain of chains) {
        console.log(`[+] Deploying on ${chain.name}`);
        const toftMinterFactory = await hre.ethers.getContractFactory(
            'TOFTMinter',
        );
        const signer = await hre.SDK.hardhatUtils.useNetwork(hre, chain.name);

        const OFTs = hre.SDK.db
            .loadLocalDeployment(tag, chain.chainId)
            .filter((e) => e.meta['isToftHost']);

        // Deploy TOFTMinter for each TOFT on the chain
        for (const OFT of OFTs) {
            console.log(`\t+for ${OFT.name}`);

            // Check if already deployed
            const prevDeployment = hre.SDK.db.getLocalDeployment(
                chain.chainId,
                `TOFTMinter_${OFT.name}`,
                tag,
            );
            if (prevDeployment && !overwrite) {
                console.log(
                    `[-] TOFTMinter already deployed on ${chain.name} at ${prevDeployment.address}, skipping`,
                );
                continue;
            }

            const toftMinter = await toftMinterFactory
                .connect(signer)
                .deploy(OFT.address);
            await toftMinter.deployed();

            // Save deployment
            hre.SDK.db.saveLocally({
                [chain.chainId]: [
                    {
                        name: `TOFTMinter_${OFT.name}`,
                        address: toftMinter.address,
                        meta: {
                            isTOFTMinter: true,
                            args: [OFT.address],
                        },
                    },
                ],
            });
            // Verify if same chain
            if (String(chain.chainId) === String(hre.network.config.chainId)) {
                console.log('\t\t+Verifying TOFTMinter');
                await hre.run('verify:verify', {
                    address: toftMinter.address,
                    constructorArguments: [OFT.address],
                    noCompile: true,
                });
            }
        }
    }

    console.log('[+] Done 🤝 [+]');

    hre.config.SDK.project = tempConf;
};
