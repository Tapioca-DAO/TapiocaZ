// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IYieldBox {
    function amountOf(address user, uint256 assetId)
        external
        view
        returns (uint256 amount);

    function assetCount() external view returns (uint256);

    function assetTotals(uint256 assetId)
        external
        view
        returns (uint256 totalShare, uint256 totalAmount);

    function assets(uint256)
        external
        view
        returns (
            uint8 tokenType,
            address contractAddress,
            address strategy,
            uint256 tokenId
        );

    function balanceOf(address, uint256) external view returns (uint256);

    function balanceOfBatch(address[] calldata owners, uint256[] calldata ids)
        external
        view
        returns (uint256[] calldata balances);

    function batch(bytes[] calldata calls, bool revertOnFail) external;

    function batchTransfer(
        address from,
        address to,
        uint256[] calldata assetIds_,
        uint256[] calldata shares_
    ) external;

    function burn(
        uint256 tokenId,
        address from,
        uint256 amount
    ) external;

    function claimOwnership(uint256 tokenId) external;

    function clonesOf(address, uint256) external view returns (address);

    function clonesOfCount(address masterContract)
        external
        view
        returns (uint256 cloneCount);

    function createToken(
        string calldata name,
        string calldata symbol,
        uint8 decimals,
        string calldata uri
    ) external returns (uint32 tokenId);

    function decimals(uint256 assetId) external view returns (uint8);

    function deploy(
        address masterContract,
        bytes calldata data,
        bool useCreate2
    ) external returns (address cloneAddress);

    function deposit(
        uint8 tokenType,
        address contractAddress,
        address strategy,
        uint256 tokenId,
        address from,
        address to,
        uint256 amount,
        uint256 share,
        uint256 minShareOut
    ) external returns (uint256 amountOut, uint256 shareOut);

    function depositAsset(
        uint256 assetId,
        address from,
        address to,
        uint256 amount,
        uint256 share,
        uint256 minShareOut
    ) external returns (uint256 amountOut, uint256 shareOut);

    function depositETH(
        address strategy,
        address to,
        uint256 minShareOut
    ) external returns (uint256 amountOut, uint256 shareOut);

    function depositETHAsset(
        uint256 assetId,
        address to,
        uint256 minShareOut
    ) external returns (uint256 amountOut, uint256 shareOut);

    function depositNFT(
        address contractAddress,
        address strategy,
        uint256 tokenId,
        address from,
        address to
    ) external returns (uint256 amountOut, uint256 shareOut);

    function depositNFTAsset(
        uint256 assetId,
        address from,
        address to
    ) external returns (uint256 amountOut, uint256 shareOut);

    function ids(
        uint8,
        address,
        address,
        uint256
    ) external view returns (uint256);

    function isApprovedForAll(address, address) external view returns (bool);

    function masterContractOf(address) external view returns (address);

    function mint(
        uint256 tokenId,
        address to,
        uint256 amount
    ) external;

    function name(uint256 assetId) external view returns (string calldata);

    function nativeTokens(uint256)
        external
        view
        returns (
            string calldata name,
            string calldata symbol,
            uint8 decimals,
            string calldata uri
        );

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4);

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4);

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);

    function owner(uint256) external view returns (address);

    function pendingOwner(uint256) external view returns (address);

    function permitToken(
        address token,
        address from,
        address to,
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function registerAsset(
        uint8 tokenType,
        address contractAddress,
        address strategy,
        uint256 tokenId
    ) external returns (uint256 assetId);

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external;

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external;

    function setApprovalForAll(address operator, bool approved) external;

    function supportsInterface(bytes4 interfaceID) external pure returns (bool);

    function symbol(uint256 assetId) external view returns (string calldata);

    function toAmount(
        uint256 assetId,
        uint256 share,
        bool roundUp
    ) external view returns (uint256 amount);

    function toShare(
        uint256 assetId,
        uint256 amount,
        bool roundUp
    ) external view returns (uint256 share);

    function totalSupply(uint256) external view returns (uint256);

    function transfer(
        address from,
        address to,
        uint256 assetId,
        uint256 share
    ) external;

    function transferMultiple(
        address from,
        address[] calldata tos,
        uint256 assetId,
        uint256[] calldata shares
    ) external;

    function transferOwnership(
        uint256 tokenId,
        address newOwner,
        bool direct,
        bool renounce
    ) external;

    function uri(uint256 assetId) external view returns (string calldata);

    function uriBuilder() external view returns (address);

    function withdraw(
        uint256 assetId,
        address from,
        address to,
        uint256 amount,
        uint256 share
    ) external returns (uint256 amountOut, uint256 shareOut);

    function withdrawNFT(
        uint256 assetId,
        address from,
        address to
    ) external returns (uint256 amountOut, uint256 shareOut);

    function wrappedNative() external view returns (address);
}
