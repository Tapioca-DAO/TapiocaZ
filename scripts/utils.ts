import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { BigNumberish, BytesLike, ethers, Signature, Wallet } from 'ethers';
import { splitSignature } from 'ethers/lib/utils';
import { existsSync, link, readFileSync, writeFileSync } from 'fs';
import { Deployment } from 'hardhat-deploy/types';
import { HardhatRuntimeEnvironment } from 'hardhat/types';
import _ from 'lodash';
import SDK from 'tapioca-sdk';
import {
    LZEndpointMock__factory,
    YieldBoxMock__factory,
} from '@tapioca-sdk/typechain/tapioca-mocks';
import config from '../hardhat.export';

export const BN = (n: any) => ethers.BigNumber.from(n);
export const generateSalt = () => ethers.utils.randomBytes(32);

export const useNetwork = async (
    hre: HardhatRuntimeEnvironment,
    network: string,
) => {
    const pk = process.env.PRIVATE_KEY;
    if (pk === undefined) throw new Error('[-] PRIVATE_KEY not set');
    const info: any = config.networks?.[network];
    if (!info)
        throw new Error(`[-] Hardhat network config not found for ${network} `);

    const provider = new hre.ethers.providers.JsonRpcProvider(
        { url: info.url },
        { chainId: info.chainId, name: `rpc-${info.chainId}` },
    );

    return new hre.ethers.Wallet(pk, provider);
};

export const useUtils = (
    hre: HardhatRuntimeEnvironment,
    signer: SignerWithAddress,
) => {
    const { ethers } = hre;

    // DEPLOYMENTS
    const deployLZEndpointMock = async (chainId: number) => {
        const LZEndpointMock = new LZEndpointMock__factory(signer);
        return await LZEndpointMock.deploy(chainId);
    };

    const deployTapiocaWrapper = async () =>
        await (
            await (
                await ethers.getContractFactory('TapiocaWrapper')
            ).deploy((await ethers.getSigners())[0].address)
        ).deployed();

    const deployYieldBoxMock = async () => {
        const YieldBoxMock = new YieldBoxMock__factory(signer);
        return await YieldBoxMock.deploy();
    };

    // UTILS
    const Tx_deployTapiocaOFT = async (
        lzEndpoint: string,
        erc20Address: string,
        yieldBoxAddress: string,
        clusterAddress: string,
        hostChainID: number,
        hostChainNetworkSigner: Wallet | SignerWithAddress,
        linked?: boolean,
    ) => {
        const erc20 = (
            await ethers.getContractAt('ERC20', erc20Address)
        ).connect(hostChainNetworkSigner);

        const erc20name =
            erc20Address == ethers.constants.AddressZero
                ? 'Ethereum'
                : await erc20.name();
        const erc20symbol =
            erc20Address == ethers.constants.AddressZero
                ? 'ETH'
                : await erc20.symbol();
        const erc20decimal =
            erc20Address == ethers.constants.AddressZero
                ? 18
                : await erc20.decimals();

        const leverageModule = await (
            await ethers.getContractFactory('BaseTOFTLeverageModule')
        ).deploy(
            lzEndpoint,
            erc20Address,
            yieldBoxAddress,
            clusterAddress,
            erc20name,
            erc20symbol,
            erc20decimal,
            hostChainID,
        );
        await leverageModule.deployed();
        const leverageDestinationModule = await (
            await ethers.getContractFactory('BaseTOFTLeverageDestinationModule')
        ).deploy(
            lzEndpoint,
            erc20Address,
            yieldBoxAddress,
            clusterAddress,
            erc20name,
            erc20symbol,
            erc20decimal,
            hostChainID,
        );
        await leverageDestinationModule.deployed();

        const marketModule = await (
            await ethers.getContractFactory('BaseTOFTMarketModule')
        ).deploy(
            lzEndpoint,
            erc20Address,
            yieldBoxAddress,
            clusterAddress,
            erc20name,
            erc20symbol,
            erc20decimal,
            hostChainID,
        );
        await marketModule.deployed();
        const marketDestinationModule = await (
            await ethers.getContractFactory('BaseTOFTMarketDestinationModule')
        ).deploy(
            lzEndpoint,
            erc20Address,
            yieldBoxAddress,
            clusterAddress,
            erc20name,
            erc20symbol,
            erc20decimal,
            hostChainID,
        );
        await marketDestinationModule.deployed();

        const optionsModule = await (
            await ethers.getContractFactory('BaseTOFTOptionsModule')
        ).deploy(
            lzEndpoint,
            erc20Address,
            yieldBoxAddress,
            clusterAddress,
            erc20name,
            erc20symbol,
            erc20decimal,
            hostChainID,
        );
        await optionsModule.deployed();
        const optionsDestinationModule = await (
            await ethers.getContractFactory('BaseTOFTOptionsDestinationModule')
        ).deploy(
            lzEndpoint,
            erc20Address,
            yieldBoxAddress,
            clusterAddress,
            erc20name,
            erc20symbol,
            erc20decimal,
            hostChainID,
        );
        await optionsDestinationModule.deployed();

        const genericModule = await (
            await ethers.getContractFactory('BaseTOFTGenericModule')
        ).deploy(
            lzEndpoint,
            erc20Address,
            yieldBoxAddress,
            clusterAddress,
            erc20name,
            erc20symbol,
            erc20decimal,
            hostChainID,
        );
        await genericModule.deployed();

        // eslint-disable-next-line @typescript-eslint/ban-ts-comment
        // @ts-ignore

        const args: Parameters<TapiocaOFT__factory['deploy']> = [
            lzEndpoint,
            erc20Address,
            yieldBoxAddress,
            clusterAddress,
            erc20name,
            erc20symbol,
            erc20decimal,
            hostChainID,
            leverageModule.address,
            leverageDestinationModule.address,
            marketModule.address,
            marketDestinationModule.address,
            optionsModule.address,
            optionsDestinationModule.address,
            genericModule.address,
        ];

        const txData = (
            await ethers.getContractFactory(
                linked ? 'mTapiocaOFT' : 'TapiocaOFT',
            )
        ).getDeployTransaction(...args).data as BytesLike;

        return { txData, args };
    };

    const attachTapiocaOFT = async (address: string, linked?: boolean) =>
        await ethers.getContractAt(
            linked ? 'mTapiocaOFT' : 'TapiocaOFT',
            address,
        );

    const newEOA = () =>
        new hre.ethers.Wallet(
            hre.ethers.Wallet.createRandom().privateKey,
            hre.ethers.provider,
        );

    return {
        deployYieldBoxMock,
        deployLZEndpointMock,
        deployTapiocaWrapper,
        Tx_deployTapiocaOFT,
        attachTapiocaOFT,
        newEOA,
    };
};

export async function getERC20PermitSignature(
    wallet: Wallet | SignerWithAddress,
    token: ERC20Permit,
    spender: string,
    value: BigNumberish = ethers.constants.MaxUint256,
    deadline = ethers.constants.MaxUint256,
    permitConfig?: {
        nonce?: BigNumberish;
        name?: string;
        chainId?: number;
        version?: string;
    },
): Promise<Signature> {
    const [nonce, name, version, chainId] = await Promise.all([
        permitConfig?.nonce ?? token.nonces(wallet.address),
        permitConfig?.name ?? token.name(),
        permitConfig?.version ?? '1',
        permitConfig?.chainId ?? wallet.getChainId(),
    ]);

    return splitSignature(
        await wallet._signTypedData(
            {
                name,
                version,
                chainId,
                verifyingContract: token.address,
            },
            {
                Permit: [
                    {
                        name: 'owner',
                        type: 'address',
                    },
                    {
                        name: 'spender',
                        type: 'address',
                    },
                    {
                        name: 'value',
                        type: 'uint256',
                    },
                    {
                        name: 'nonce',
                        type: 'uint256',
                    },
                    {
                        name: 'deadline',
                        type: 'uint256',
                    },
                ],
            },
            {
                owner: wallet.address,
                spender,
                value,
                nonce,
                deadline,
            },
        ),
    );
}
