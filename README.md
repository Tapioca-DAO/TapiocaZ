# TapiocaZ 🍹 🤙

Tapioca harnessing LayerZero omni-chain infrastructure 🤯

- [TapiocaWrapper](docs/TapiocaWrapper.md) Handle the deployment of `TOFT` contracts and execution of its `onlyOwner` functions.
- [TapiocaOFT](docs/TapiocaOFT.md) `OFT20`, Layer-Zero superset of `ERC20`. Handles the `wrap` and `unwrap` of a desired `ERC20`.

*Note: Current tasks/contracts are designed so that a TOFT works best on a support LZ chain and Optimism only*
## Flow of deployment 
1. Deploy the `TapiocaWrapper` contract on the host chain of the `ERC20`, and the chain where you want it to be present too.
```
npx hardhat deploy --network '...'
```
2. Whitelist the `ERC20` that you want to support in [constants](./scripts/constants.ts)
3. Deploy the `TapiocaOFT` contract on the host chain .
```
$ npx hardhat deployTOFT --erc20 '...' --lzChainId '...' --network '...'
```
4. Repeat the process above and deploy it on any other chain you want it to be present.


## Individual operations
### Deploy a TOFT

Deploy a TOFT contract to the specified network. It'll also deploy it to Tapioca host chain (Optimism, chainID 10).
A document will be created in the `deployments.json` file.
- `erc20`: The address of the `ERC20` to be wrapped.
- `lzChainId`: The Layer-Zero chain ID of the host chain.
- `network`: The network (must be the host chain).
```
$ npx hardhat deployTOFT --erc20 '...' --lzChainId '...' --network '...'
```
### List TOFTs

List the deployments of a `TapiocaWrapper` given a network.
- `network`: The network (must be the host chain).
```
$ npx hardhat listDeploy --network '...'
```

### Wrap an `ERC20` 

Wrap an `ERC20` into a `TOFT`.
- `toft`: The address of the toft.
- `amount`: The amount of `ERC20` to wrap in wei.
- `network`: The network (must be the host chain).
```
$ npx hardhat wrap --toft '...' --amount '...' --network '...'
```

### Send a `TOFT` 

Transfer a TOFT amount between chains.
- `toft`: The address of the toft.
- `to`: The address to send to.
- `amount`: The amount of `ERC20` to wrap in wei.
- `network`: The network (must be the host chain). It'll automatically pick the other chain from [deployments.json](./deployments.json).
```
$ npx hardhat sendFrom --toft '...' --to '...' --amount '...' --network '...'
```