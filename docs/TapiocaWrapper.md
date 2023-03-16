# TapiocaWrapper









## Methods

### createTOFT

```solidity
function createTOFT(address _erc20, bytes _bytecode, bytes32 _salt, bool _linked) external nonpayable
```

Deploy a new TOFT contract. Callable only by the owner.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _erc20 | address | The ERC20 to wrap. |
| _bytecode | bytes | The executable bytecode of the TOFT contract. |
| _salt | bytes32 | Create2 salt. |
| _linked | bool | undefined |

### executeCalls

```solidity
function executeCalls(TapiocaWrapper.ExecutionCall[] _call) external payable returns (bool success, bytes[] results)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _call | TapiocaWrapper.ExecutionCall[] | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| success | bool | undefined |
| results | bytes[] | undefined |

### executeTOFT

```solidity
function executeTOFT(address _toft, bytes _bytecode, bool _revertOnFailure) external payable returns (bool success, bytes result)
```

Execute the `_bytecode` against the `_toft`. Callable only by the owner.

*Used to call derived OFT functions to a TOFT contract.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _toft | address | The TOFT contract to execute against. |
| _bytecode | bytes | The executable bytecode of the TOFT contract. |
| _revertOnFailure | bool | Whether to revert on failure. |

#### Returns

| Name | Type | Description |
|---|---|---|
| success | bool | If the execution was successful. |
| result | bytes | The error message if the execution failed. |

### harvestFees

```solidity
function harvestFees() external nonpayable
```

Harvest fees from all the deployed TOFT contracts. Fees are transferred to the owner.




### harvestableTapiocaOFTsLength

```solidity
function harvestableTapiocaOFTsLength() external view returns (uint256)
```

Return the number of harvestable TOFT contracts deployed on the current chain.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### lastTOFT

```solidity
function lastTOFT() external view returns (contract ITapiocaOFT)
```

Return the latest TOFT contract deployed on the current chain.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract ITapiocaOFT | undefined |

### mngmtFee

```solidity
function mngmtFee() external view returns (uint256)
```

Management fee for a wrap operation. In BPS.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### mngmtFeeFraction

```solidity
function mngmtFeeFraction() external view returns (uint256)
```

Denominator for `mngmtFee`.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### owner

```solidity
function owner() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### setMngmtFee

```solidity
function setMngmtFee(uint256 _mngmtFee) external nonpayable
```

Set the management fee for a wrap operation.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _mngmtFee | uint256 | The new management fee for a wrap operation. In BPS. |

### setOwner

```solidity
function setOwner(address newOwner) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| newOwner | address | undefined |

### tapiocaOFTLength

```solidity
function tapiocaOFTLength() external view returns (uint256)
```

Return the number of TOFT contracts deployed on the current chain.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### tapiocaOFTs

```solidity
function tapiocaOFTs(uint256) external view returns (contract ITapiocaOFT)
```

Array of deployed TOFT contracts.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract ITapiocaOFT | undefined |

### tapiocaOFTsByErc20

```solidity
function tapiocaOFTsByErc20(address) external view returns (contract ITapiocaOFT)
```

Map of deployed TOFT contracts by ERC20.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract ITapiocaOFT | undefined |



## Events

### CreateOFT

```solidity
event CreateOFT(contract ITapiocaOFT indexed _tapiocaOFT, address indexed _erc20)
```

Called when a new OFT is deployed.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _tapiocaOFT `indexed` | contract ITapiocaOFT | undefined |
| _erc20 `indexed` | address | undefined |

### HarvestFees

```solidity
event HarvestFees(address indexed _caller)
```

Called when fees are harvested.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _caller `indexed` | address | undefined |

### OwnerUpdated

```solidity
event OwnerUpdated(address indexed user, address indexed newOwner)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| user `indexed` | address | undefined |
| newOwner `indexed` | address | undefined |

### SetFees

```solidity
event SetFees(uint256 _newFee)
```

Called when fees are changed.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _newFee  | uint256 | undefined |



## Errors

### TapiocaWrapper__AlreadyDeployed

```solidity
error TapiocaWrapper__AlreadyDeployed(address _erc20)
```

If the TOFT is already deployed.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _erc20 | address | undefined |

### TapiocaWrapper__FailedDeploy

```solidity
error TapiocaWrapper__FailedDeploy()
```

Failed to deploy the TapiocaWrapper contract.




### TapiocaWrapper__MngmtFeeTooHigh

```solidity
error TapiocaWrapper__MngmtFeeTooHigh()
```

The management fee is too high. Currently set to a max of 50 BPS or 0.5%.




### TapiocaWrapper__NoTOFTDeployed

```solidity
error TapiocaWrapper__NoTOFTDeployed()
```

No TOFT has been deployed yet.




### TapiocaWrapper__TOFTExecutionFailed

```solidity
error TapiocaWrapper__TOFTExecutionFailed(bytes message)
```

The TapiocaOFT execution failed.



#### Parameters

| Name | Type | Description |
|---|---|---|
| message | bytes | undefined |


