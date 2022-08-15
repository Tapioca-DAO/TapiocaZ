# TapiocaZ 🍹 🤙

Tapioca harnessing LayerZero infrastructure to go Omni-Chain 🤯

### Deploy a TOFT

Deploy a TOFT contract to the specified network. It'll also deploy it to Tapioca host chain (Optimism, chainID 10).
A document will be created in the `deployments.json` file.

```
$ npx hardhat deployTOFT --erc20 '...' --lzChainId '...' --network '...'
```
### List TOFTs

List the deployments of a `TapiocaWrapper` given a network
```
$ npx hardhat listDeploy --network '...'
```