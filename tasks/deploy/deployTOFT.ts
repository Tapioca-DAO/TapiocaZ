import { BytesLike } from 'ethers';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import inquirer from 'inquirer';
import { TContract } from 'tapioca-sdk/dist/shared';
import { v4 as uuidv4 } from 'uuid';

import { useNetwork, useUtils } from '../../scripts/utils';
import { TapiocaOFT, TapiocaWrapper } from '../../typechain';
import { loadVM } from '../utils';
import SDK from 'tapioca-sdk';

export interface ITOFTDeployment extends TContract {
    meta: {
        args: any[];
        isToftHost: boolean;
        isMerged: boolean;
        isToft: boolean;
    };
}
export const deployTOFT__task = async (
    args: {
        isNative?: boolean;
        isMerged?: boolean;
        throughMultisig?: boolean;
        overrideOptions?: boolean;
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

    const project = hre.SDK.config.TAPIOCA_PROJECTS[2];
    const subrepo = hre.SDK.db.SUBREPO_GLOBAL_DB_PATH;

    const chainInfo = hre.SDK.utils.getChainBy(
        'chainId',
        await hre.getChainId(),
    );
    const yieldBox = await hre.SDK.db
        .loadGlobalDeployment(tag, project, chainInfo.chainId)
        .find((e) => e.name === 'YieldBox');
    if (!yieldBox) {
        throw '[-] YieldBox not found';
    }

    const ercAddress = await loadERC20(hre, args.isNative);
    const { hostChainName, isCurrentChainHost, hostChainContractInfo } =
        await getHostChainInfo(hre, ercAddress, tag);

    if (!isCurrentChainHost && !args.isNative) {
        await validateErc20Address(
            hre,
            hostChainName,
            hostChainContractInfo!.address,
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
        tag,
        tapiocaWrapper,
        ercAddress,
        toftDeployInfo.txData,
        args.throughMultisig,
        args.isMerged,
        args.overrideOptions,
    );
    await saveDeployedTOFT(hre, tag, deployedTOFT, {
        isToftHost: isCurrentChainHost,
        isMerged: Boolean(args.isMerged),
        isToft: true,
        args: toftDeployInfo.args,
    });

    console.log('[+] TOFT deployed successfully.');
    if (isCurrentChainHost) {
        console.log(
            '[+] You can execute this task again on other networks to link them.',
        );
    }
    console.log(
        '[+] When finished with all the TOFT deployment, use the following command to configure it:',
    );
    console.log(
        '\t- setLZConfig: To set the trustedRemote & minDstGas for the supported packet types',
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
    } catch (e) {
        throw new Error(
            '[-] Make sure Balancer is deployed on the current chain\n',
        );
    }
    try {
        await hre.SDK.hardhatUtils.getLocalContract(hre, 'TapiocaWrapper', tag);
    } catch (e) {
        throw new Error(
            '[-] Make sure TapiocaWrapper is deployed on the current chain\n',
        );
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
    if (!isCurrentChainHost && !hostChainContractInfo) {
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
    const signer = (await hre.ethers.getSigners())[0];
    const utils = useUtils(hre, signer);

    console.log('[+] Getting TOFT creation bytecode');
    // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
    const hostChainInfo = hre.SDK.utils
        .getSupportedChains()
        .find((e) => e.name === hostChainName)!;
    // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
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
    tag: string,
    tapiocaWrapper: TapiocaWrapper,
    ercAddress: string,
    deployBytecode: BytesLike,
    throughMultisig?: boolean,
    isMerged?: boolean,
    overrideOptions?: boolean,
) {
    console.log('[+] Deploying TOFT');
    if (throughMultisig) {
        const calldata = tapiocaWrapper.interface.encodeFunctionData(
            'createTOFT',
            [
                ercAddress,
                deployBytecode,
                hre.ethers.utils.solidityKeccak256(['string'], [uuidv4()]),
                Boolean(isMerged),
            ],
        );

        const deployerVM = await loadVM(hre, tag);

        await deployerVM.submitTransactionThroughMultisig(
            tapiocaWrapper.address,
            // eslint-disable-next-line prettier/prettier
            calldata);
    } else {
        await (
            await tapiocaWrapper.createTOFT(
                ercAddress,
                deployBytecode,
                hre.ethers.utils.solidityKeccak256(['string'], [uuidv4()]),
                Boolean(isMerged),
                overrideOptions
                    ? hre.SDK.utils.getOverrideOptions(await hre.getChainId())
                    : {},
            )
        ).wait(3);
    }

    const deployedToft = await hre.ethers.getContractAt(
        'TapiocaOFT',
        await tapiocaWrapper.lastTOFT(),
    );
    console.log(`[+] TOFT ${await deployedToft.name()} created`);

    return deployedToft;
}

async function saveDeployedTOFT(
    hre: HardhatRuntimeEnvironment,
    tag: string,
    deployedTOFT: TapiocaOFT,
    meta: ITOFTDeployment['meta'],
) {
    const deployerVM = await loadVM(hre, tag);

    deployerVM.load([
        buildTOFTDeployment({
            name: await deployedTOFT.name(),
            address: deployedTOFT.address,
            meta,
        }),
    ]);
    deployerVM.save();

    const { wantToVerify } = await inquirer.prompt({
        type: 'confirm',
        name: 'wantToVerify',
        message: 'Do you want to verify the contracts?',
    });
    if (wantToVerify) {
        try {
            await deployerVM.verify();
        } catch {
            console.log('[-] Verification failed');
        }
    }
}
