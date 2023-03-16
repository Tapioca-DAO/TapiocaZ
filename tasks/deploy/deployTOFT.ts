import { BytesLike, ethers } from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import inquirer from 'inquirer';
import { typechain } from 'tapioca-sdk';
import { TContract } from 'tapioca-sdk/dist/shared';
import { v4 as uuidv4 } from 'uuid';

import { useNetwork, useUtils } from '../../scripts/utils';
import { TapiocaOFT, TapiocaWrapper } from '../../typechain';

export interface ITOFTDeployment extends TContract {
    meta: {
        args: any[];
        isToftHost: boolean;
        isMerged: boolean;
    };
}
export const deployTOFT__task = async (
    args: {
        isNative?: boolean;
        isMerged?: boolean;
    },
    hre: HardhatRuntimeEnvironment,
) => {
    console.log('\n[+] Initiating TOFT deployment');
    const tag = await hre.SDK.hardhatUtils.askForTag(hre, 'local');
    if (!tag)
        throw new Error(
            '[-] No local deployment found for TapiocaWrapper & Balancer. Aborting',
        );

    checkIfExists(hre, tag, args.isMerged);

    /**
     * Load variables
     */
    const utils = useUtils(hre);

    // TODO - Use global YieldBox address from tapioca-bar when it's ready
    const yieldBox = await utils.deployYieldBoxMock();
    const ercAddress = await loadERC20(hre, args.isNative);
    const { hostChainName, isCurrentChainHost, hostChainContractInfo } =
        await getHostChainInfo(hre, ercAddress, tag);

    if (!args.isNative) {
        await validateErc20Address(
            hre,
            hostChainName,
            hostChainContractInfo.address,
        );
    }

    /**
     * Deploy TOFT
     */
    const { tapiocaWrapper, toftDeployInfo } = await getPreDeploymentInfo(
        hre,
        hostChainName,
        tag,
        ercAddress,
        yieldBox.address,
        args,
    );
    const deployedTOFT = await initiateTOFTDeployment(
        hre,
        tapiocaWrapper,
        ercAddress,
        toftDeployInfo.txData,
        args.isMerged,
    );
    await saveDeployedTOFT(hre, tag, deployedTOFT, {
        isToftHost: isCurrentChainHost,
        isMerged: Boolean(args.isMerged),
        args: toftDeployInfo.args,
    });

    console.log(
        '[+] TOFT deployed successfully. When finished with all the TOFT deployment, use the following command to configure it:',
    );
    console.log(
        '\t- batchSetAdapterParam: To set the minDstGas for the supported packet types',
    );
    console.log(
        '\t- batchSetTrustedRemote: To set the minDstGas for the supported packet types',
    );
    console.log(
        '[+] Use the hardhat batchSetTrustedRemote --help to get help!\n',
    );
};

function buildTOFTDeployment(args: ITOFTDeployment): ITOFTDeployment {
    return args;
}

/**
 * Check if TapiocaWrapper and Balancer contracts exist
 */
async function checkIfExists(
    hre: HardhatRuntimeEnvironment,
    tag: string,
    isMerged?: boolean,
) {
    try {
        if (isMerged) {
            await hre.SDK.hardhatUtils.getLocalContract(hre, 'Balancer', tag);
        }
        await hre.SDK.hardhatUtils.getLocalContract(hre, 'TapiocaWrapper', tag);
    } catch (e) {
        console.log(e, 'Please deploy the deploy it first');
        return;
    }
}

/**
 * Ask the user for the ERC20 address and validate it's the correct one
 */
async function loadERC20(hre: HardhatRuntimeEnvironment, isNative?: boolean) {
    let ercAddress = hre.ethers.constants.AddressZero;
    if (!isNative) {
        ercAddress = (
            await inquirer.prompt({
                type: 'input',
                name: 'ercAddress',
                message: 'Enter the ERC20 address',
            })
        ).ercAddress;
    }
    return ercAddress;
}

/**
 * Ask the user host chain name of the TOFT and check if it's the current chain
 */
async function getHostChainInfo(
    hre: HardhatRuntimeEnvironment,
    ercAddress: string,
    tag: string,
) {
    const { hostChainName } = await inquirer.prompt({
        type: 'list',
        name: 'hostChainName',
        message: 'Select the host chain',
        choices: hre.SDK.utils.getSupportedChains().map((e) => e.name),
    });
    let isCurrentChainHost = false;
    if (hostChainName === hre.network.name) {
        const { goOn } = await inquirer.prompt({
            type: 'confirm',
            name: 'goOn',
            message:
                'Using the current chain as host chain. Do you want to continue?',
        });
        if (!goOn) throw new Error('[-] Aborted');
        isCurrentChainHost = true;
    }

    // Get Host Chain ID
    const hostChainId = hre.SDK.utils.getChainBy(
        'name',
        hostChainName,
    )?.chainId;
    if (!hostChainId) throw new Error('[-] Invalid host chain name');

    // Get Host Chain TapiocaOFT contract
    const hostChainContractInfo = hre.SDK.db
        .loadLocalDeployment(tag, hostChainId)
        .filter((e) => e.meta.isToftHost)
        .find((e) => e.meta.args.includes(ercAddress));
    if (!hostChainContractInfo) {
        throw new Error(
            `[-] No TapiocaOFT contract found for ${ercAddress} on ${hostChainName}`,
        );
    }

    return {
        hostChainName,
        hostChainContractInfo,
        isCurrentChainHost,
    };
}

/**
 * Ask the user for the TOFT address and validate it's the correct one
 */
async function validateErc20Address(
    hre: HardhatRuntimeEnvironment,
    hostChainName: string,
    address: string,
) {
    const network = await useNetwork(hre, hostChainName);
    const erc20 = await hre.ethers.getContractAt('ERC20', address, network);
    const name = await erc20.name();
    const symbol = await erc20.symbol();
    const decimal = await erc20.decimals();

    const { isValid } = await inquirer.prompt({
        type: 'confirm',
        name: 'isValid',
        message: `Is this the correct ERC20?: ${name} (${symbol}) with ${decimal} decimals`,
    });
    if (!isValid) {
        throw new Error('[-] Invalid ERC20');
    }
}

/**
 * Get pre deployment info, such as the bytecode and the chain info
 */
async function getPreDeploymentInfo(
    hre: HardhatRuntimeEnvironment,
    hostChainName: string,
    tag: string,
    ercAddress: string,
    yieldBoxAddress: string,
    args: { isMerged?: boolean; isNative?: boolean },
) {
    const utils = useUtils(hre);

    console.log('[+] Getting TOFT creation bytecode');
    const hostChainInfo = hre.SDK.utils
        .getSupportedChains()
        .find((e) => e.name === hostChainName)!;
    const currentChainInfo = hre.SDK.utils
        .getSupportedChains()
        .find((e) => e.name === hre.network.name)!;

    const { contract: tapiocaWrapper } =
        await hre.SDK.hardhatUtils.getLocalContract<TapiocaWrapper>(
            hre,
            'TapiocaWrapper',
            tag,
        );

    const toftDeployInfo = await utils.Tx_deployTapiocaOFT(
        currentChainInfo.address,
        Boolean(args.isNative),
        ercAddress,
        yieldBoxAddress,
        Number(hostChainInfo.chainId),
        await useNetwork(hre, hostChainName),
        args.isMerged,
    );

    return { hostChainInfo, currentChainInfo, tapiocaWrapper, toftDeployInfo };
}

/**
 * Deploy a TOFT using the TapiocaWrapper
 */
async function initiateTOFTDeployment(
    hre: HardhatRuntimeEnvironment,
    tapiocaWrapper: TapiocaWrapper,
    ercAddress: string,
    deployBytecode: BytesLike,
    isMerged?: boolean,
) {
    console.log('[+] Deploying TOFT');
    const txCreateToft = await (
        await tapiocaWrapper.createTOFT(
            ercAddress,
            deployBytecode,
            hre.ethers.utils.solidityKeccak256(['string'], [uuidv4()]),
            Boolean(isMerged),
        )
    ).wait(3);
    const deployedToft = await hre.ethers.getContractAt(
        'TapiocaOFT',
        await tapiocaWrapper.lastTOFT(),
    );
    console.log(
        `[+] TOFT ${await deployedToft.name()} created on hash: ${
            txCreateToft.transactionHash
        }`,
    );

    return deployedToft;
}

async function saveDeployedTOFT(
    hre: HardhatRuntimeEnvironment,
    tag: string,
    deployedTOFT: TapiocaOFT,
    meta: ITOFTDeployment['meta'],
) {
    const deployerVM = new hre.SDK.DeployerVM(hre, {
        bytecodeSizeLimit: 90_000,
        multicall: typechain.Multicall.Multicall3__factory.connect(
            hre.SDK.config.MULTICALL_ADDRESS,
            (await hre.ethers.getSigners())[0],
        ),
        tag,
    });

    deployerVM.load([
        buildTOFTDeployment({
            name: await deployedTOFT.name(),
            address: deployedTOFT.address,
            meta,
        }),
    ]);
    deployerVM.save();
    await deployerVM.verify();
}
