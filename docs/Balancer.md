# Balancer





Transfers tokens to other layers through Stargate



## Methods

### addRebalanceAmount

```solidity
function addRebalanceAmount(address _srcOft, uint16 _dstChainId, uint256 _amount) external nonpayable
```

assings more rebalanceable amount for TOFT



#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcOft | address | the source TOFT address |
| _dstChainId | uint16 | the destination LayerZero id |
| _amount | uint256 | the rebalanced amount |

### checker

```solidity
function checker(address payable _srcOft, uint16 _dstChainId) external view returns (bool canExec, bytes execPayload)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcOft | address payable | undefined |
| _dstChainId | uint16 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| canExec | bool | undefined |
| execPayload | bytes | undefined |

### connectedOFTs

```solidity
function connectedOFTs(address, uint16) external view returns (uint256 srcPoolId, uint256 dstPoolId, address dstOft, uint256 rebalanceable)
```

current OFT =&gt; chain =&gt; destination OFT

*chain ids (https://stargateprotocol.gitbook.io/stargate/developers/chain-ids):         - Ethereum: 101         - BNB: 102         - Avalanche: 106         - Polygon: 109         - Arbitrum: 110         - Optimism: 111         - Fantom: 112         - Metis: 151     pool ids https://stargateprotocol.gitbook.io/stargate/developers/pool-ids*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |
| _1 | uint16 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| srcPoolId | uint256 | undefined |
| dstPoolId | uint256 | undefined |
| dstOft | address | undefined |
| rebalanceable | uint256 | undefined |

### initConnectedOFT

```solidity
function initConnectedOFT(address _srcOft, uint16 _dstChainId, address _dstOft, bytes _ercData) external nonpayable
```

registeres mTapiocaOFT for rebalancing



#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcOft | address | the source TOFT address |
| _dstChainId | uint16 | the destination LayerZero id |
| _dstOft | address | the destination TOFT address |
| _ercData | bytes | custom send data |

### instantRedeemLocal

```solidity
function instantRedeemLocal(uint16 _srcPoolId, uint256 _amountLP, address _to) external nonpayable returns (uint256 amountSD)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcPoolId | uint16 | undefined |
| _amountLP | uint256 | undefined |
| _to | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| amountSD | uint256 | undefined |

### owner

```solidity
function owner() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### rebalance

```solidity
function rebalance(address payable _srcOft, uint16 _dstChainId, uint256 _slippage, uint256 _amount, bytes _ercData) external payable
```

performs a rebalance operation

*callable only by the owner*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcOft | address payable | the source TOFT address |
| _dstChainId | uint16 | the destination LayerZero id |
| _slippage | uint256 | the destination LayerZero id |
| _amount | uint256 | the rebalanced amount |
| _ercData | bytes | custom send data |

### redeemLocal

```solidity
function redeemLocal(uint16 _dstChainId, uint256 _srcPoolId, uint256 _dstPoolId, address payable _refundAddress, uint256 _amountLP, bytes _to, IStargateRouterBase.lzTxObj _lzTxParams) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId | uint16 | undefined |
| _srcPoolId | uint256 | undefined |
| _dstPoolId | uint256 | undefined |
| _refundAddress | address payable | undefined |
| _amountLP | uint256 | undefined |
| _to | bytes | undefined |
| _lzTxParams | IStargateRouterBase.lzTxObj | undefined |

### redeemRemote

```solidity
function redeemRemote(uint16 _dstChainId, uint256 _srcPoolId, uint256 _dstPoolId, address payable _refundAddress, uint256 _amountLP, uint256 _minAmountLD, bytes _to, IStargateRouterBase.lzTxObj _lzTxParams) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId | uint16 | undefined |
| _srcPoolId | uint256 | undefined |
| _dstPoolId | uint256 | undefined |
| _refundAddress | address payable | undefined |
| _amountLP | uint256 | undefined |
| _minAmountLD | uint256 | undefined |
| _to | bytes | undefined |
| _lzTxParams | IStargateRouterBase.lzTxObj | undefined |

### retryRevert

```solidity
function retryRevert(uint16 _srcChainId, bytes _srcAddress, uint256 _nonce) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _srcAddress | bytes | undefined |
| _nonce | uint256 | undefined |

### router

```solidity
function router() external view returns (contract IStargateRouter)
```

Stargate router address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IStargateRouter | undefined |

### routerETH

```solidity
function routerETH() external view returns (contract IStargateRouter)
```

StargetETH router address




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IStargateRouter | undefined |

### setOwner

```solidity
function setOwner(address newOwner) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| newOwner | address | undefined |



## Events

### ConnectedChainUpdated

```solidity
event ConnectedChainUpdated(address indexed _srcOft, uint16 indexed _dstChainId, address indexed _dstOft)
```

event emitted when mTapiocaOFT is initialized



#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcOft `indexed` | address | undefined |
| _dstChainId `indexed` | uint16 | undefined |
| _dstOft `indexed` | address | undefined |

### OwnerUpdated

```solidity
event OwnerUpdated(address indexed user, address indexed newOwner)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| user `indexed` | address | undefined |
| newOwner `indexed` | address | undefined |

### RebalanceAmountUpdated

```solidity
event RebalanceAmountUpdated(address indexed _srcOft, uint16 indexed _dstChainId, uint256 indexed _amount, uint256 _totalAmount)
```

event emitted when max rebalanceable amount is updated



#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcOft `indexed` | address | undefined |
| _dstChainId `indexed` | uint16 | undefined |
| _amount `indexed` | uint256 | undefined |
| _totalAmount  | uint256 | undefined |

### Rebalanced

```solidity
event Rebalanced(address indexed _srcOft, uint16 indexed _dstChainId, uint256 indexed _slippage, uint256 _amount, bool _isNative)
```

event emitted when a rebalance operation is performed

*rebalancing means sending an amount of the underlying token to one of the connected chains*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcOft `indexed` | address | undefined |
| _dstChainId `indexed` | uint16 | undefined |
| _slippage `indexed` | uint256 | undefined |
| _amount  | uint256 | undefined |
| _isNative  | bool | undefined |



## Errors

### DestinationNotValid

```solidity
error DestinationNotValid()
```

error thrown when chain destination is not valid




### DestinationOftNotValid

```solidity
error DestinationOftNotValid()
```






### ExceedsBalance

```solidity
error ExceedsBalance()
```

error thrown when value exceeds balance




### FeeAmountNotSet

```solidity
error FeeAmountNotSet()
```

error thrown when fee amount is not set




### PoolInfoRequired

```solidity
error PoolInfoRequired()
```






### RebalanceAmountNotSet

```solidity
error RebalanceAmountNotSet()
```






### RouterNotValid

```solidity
error RouterNotValid()
```

error thrown when IStargetRouter address is not valid




### SlippageNotValid

```solidity
error SlippageNotValid()
```

error thrown when dex slippage is not valid





