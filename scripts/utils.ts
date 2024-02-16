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
    const newEOA = () =>
        new hre.ethers.Wallet(
            hre.ethers.Wallet.createRandom().privateKey,
            hre.ethers.provider,
        );

    const deployYieldBoxMock = async () => {
        const YieldBoxMock = new YieldBoxMock__factory(signer);
        return await YieldBoxMock.deploy();
    };

    return {
        newEOA,
        deployYieldBoxMock,
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
