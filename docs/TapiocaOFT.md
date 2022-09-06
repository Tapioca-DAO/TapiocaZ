# TapiocaOFT









## Methods

### allowance

```solidity
function allowance(address owner, address spender) external view returns (uint256)
```



*See {IERC20-allowance}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner | address | undefined |
| spender | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### approve

```solidity
function approve(address spender, uint256 amount) external nonpayable returns (bool)
```



*See {IERC20-approve}. NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on `transferFrom`. This is semantically equivalent to an infinite approval. Requirements: - `spender` cannot be the zero address.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| spender | address | undefined |
| amount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### balanceOf

```solidity
function balanceOf(address account) external view returns (uint256)
```



*See {IERC20-balanceOf}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| account | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### circulatingSupply

```solidity
function circulatingSupply() external view returns (uint256)
```



*returns the circulating amount of tokens on current chain*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### decimals

```solidity
function decimals() external view returns (uint8)
```

Decimal number of the ERC20




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | undefined |

### decreaseAllowance

```solidity
function decreaseAllowance(address spender, uint256 subtractedValue) external nonpayable returns (bool)
```



*Atomically decreases the allowance granted to `spender` by the caller. This is an alternative to {approve} that can be used as a mitigation for problems described in {IERC20-approve}. Emits an {Approval} event indicating the updated allowance. Requirements: - `spender` cannot be the zero address. - `spender` must have allowance for the caller of at least `subtractedValue`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| spender | address | undefined |
| subtractedValue | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### erc20

```solidity
function erc20() external view returns (contract IERC20)
```

The ERC20 to wrap.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IERC20 | undefined |

### estimateFees

```solidity
function estimateFees(uint256 _feeBps, uint256 _feeFraction, uint256 _amount) external pure returns (uint256)
```

Estimate the management fees for a wrap operation.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _feeBps | uint256 | undefined |
| _feeFraction | uint256 | undefined |
| _amount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### estimateSendFee

```solidity
function estimateSendFee(uint16 _dstChainId, bytes _toAddress, uint256 _amount, bool _useZro, bytes _adapterParams) external view returns (uint256 nativeFee, uint256 zroFee)
```



*estimate send token `_tokenId` to (`_dstChainId`, `_toAddress`) _dstChainId - L0 defined chain id to send tokens too _toAddress - dynamic bytes array which contains the address to whom you are sending tokens to on the dstChain _amount - amount of the tokens to transfer _useZro - indicates to use zro to pay L0 fees _adapterParam - flexible bytes array to indicate messaging adapter services in L0*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId | uint16 | undefined |
| _toAddress | bytes | undefined |
| _amount | uint256 | undefined |
| _useZro | bool | undefined |
| _adapterParams | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| nativeFee | uint256 | undefined |
| zroFee | uint256 | undefined |

### failedMessages

```solidity
function failedMessages(uint16, bytes, uint64) external view returns (bytes32)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |
| _1 | bytes | undefined |
| _2 | uint64 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### forceResumeReceive

```solidity
function forceResumeReceive(uint16 _srcChainId, bytes _srcAddress) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _srcAddress | bytes | undefined |

### getConfig

```solidity
function getConfig(uint16 _version, uint16 _chainId, address, uint256 _configType) external view returns (bytes)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _version | uint16 | undefined |
| _chainId | uint16 | undefined |
| _2 | address | undefined |
| _configType | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes | undefined |

### harvestFees

```solidity
function harvestFees() external nonpayable
```

Harvest the fees collected by the contract. Called only on main chain.




### hostChainID

```solidity
function hostChainID() external view returns (uint256)
```

The host chain ID of the ERC20, will be used only on OP chain.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### increaseAllowance

```solidity
function increaseAllowance(address spender, uint256 addedValue) external nonpayable returns (bool)
```



*Atomically increases the allowance granted to `spender` by the caller. This is an alternative to {approve} that can be used as a mitigation for problems described in {IERC20-approve}. Emits an {Approval} event indicating the updated allowance. Requirements: - `spender` cannot be the zero address.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| spender | address | undefined |
| addedValue | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### isHostChain

```solidity
function isHostChain() external view returns (bool)
```

Check if the current chain is the main chain of the ERC20.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### isTrustedRemote

```solidity
function isTrustedRemote(uint16 _srcChainId, bytes _srcAddress) external view returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _srcAddress | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### lzEndpoint

```solidity
function lzEndpoint() external view returns (contract ILayerZeroEndpoint)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract ILayerZeroEndpoint | undefined |

### lzReceive

```solidity
function lzReceive(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _srcAddress | bytes | undefined |
| _nonce | uint64 | undefined |
| _payload | bytes | undefined |

### name

```solidity
function name() external view returns (string)
```



*Returns the name of the token.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### nonblockingLzReceive

```solidity
function nonblockingLzReceive(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _srcAddress | bytes | undefined |
| _nonce | uint64 | undefined |
| _payload | bytes | undefined |

### owner

```solidity
function owner() external view returns (address)
```



*Returns the address of the current owner.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### renounceOwnership

```solidity
function renounceOwnership() external nonpayable
```



*Leaves the contract without owner. It will not be possible to call `onlyOwner` functions anymore. Can only be called by the current owner. NOTE: Renouncing ownership will leave the contract without an owner, thereby removing any functionality that is only available to the owner.*


### retryMessage

```solidity
function retryMessage(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _srcAddress | bytes | undefined |
| _nonce | uint64 | undefined |
| _payload | bytes | undefined |

### sendFrom

```solidity
function sendFrom(address _from, uint16 _dstChainId, bytes _toAddress, uint256 _amount, address payable _refundAddress, address _zroPaymentAddress, bytes _adapterParams) external payable
```



*send `_amount` amount of token to (`_dstChainId`, `_toAddress`) from `_from` `_from` the owner of token `_dstChainId` the destination chain identifier `_toAddress` can be any size depending on the `dstChainId`. `_amount` the quantity of tokens in wei `_refundAddress` the address LayerZero refunds if too much message fee is sent `_zroPaymentAddress` set to address(0x0) if not paying in ZRO (LayerZero Token) `_adapterParams` is a flexible bytes array to indicate messaging adapter services*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _from | address | undefined |
| _dstChainId | uint16 | undefined |
| _toAddress | bytes | undefined |
| _amount | uint256 | undefined |
| _refundAddress | address payable | undefined |
| _zroPaymentAddress | address | undefined |
| _adapterParams | bytes | undefined |

### setConfig

```solidity
function setConfig(uint16 _version, uint16 _chainId, uint256 _configType, bytes _config) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _version | uint16 | undefined |
| _chainId | uint16 | undefined |
| _configType | uint256 | undefined |
| _config | bytes | undefined |

### setReceiveVersion

```solidity
function setReceiveVersion(uint16 _version) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _version | uint16 | undefined |

### setSendVersion

```solidity
function setSendVersion(uint16 _version) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _version | uint16 | undefined |

### setTrustedRemote

```solidity
function setTrustedRemote(uint16 _srcChainId, bytes _srcAddress) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _srcAddress | bytes | undefined |

### supportsInterface

```solidity
function supportsInterface(bytes4 interfaceId) external view returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| interfaceId | bytes4 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### symbol

```solidity
function symbol() external view returns (string)
```



*Returns the symbol of the token, usually a shorter version of the name.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### tapiocaWrapper

```solidity
function tapiocaWrapper() external view returns (contract TapiocaWrapper)
```

The TapiocaWrapper contract, owner of this contract.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract TapiocaWrapper | undefined |

### totalFees

```solidity
function totalFees() external view returns (uint256)
```

Total fees amassed by this contract, in `erc20`.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### totalSupply

```solidity
function totalSupply() external view returns (uint256)
```



*See {IERC20-totalSupply}.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### transfer

```solidity
function transfer(address to, uint256 amount) external nonpayable returns (bool)
```



*See {IERC20-transfer}. Requirements: - `to` cannot be the zero address. - the caller must have a balance of at least `amount`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| to | address | undefined |
| amount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### transferFrom

```solidity
function transferFrom(address from, address to, uint256 amount) external nonpayable returns (bool)
```



*See {IERC20-transferFrom}. Emits an {Approval} event indicating the updated allowance. This is not required by the EIP. See the note at the beginning of {ERC20}. NOTE: Does not update the allowance if the current allowance is the maximum `uint256`. Requirements: - `from` and `to` cannot be the zero address. - `from` must have a balance of at least `amount`. - the caller must have allowance for ``from``&#39;s tokens of at least `amount`.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| from | address | undefined |
| to | address | undefined |
| amount | uint256 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### transferOwnership

```solidity
function transferOwnership(address newOwner) external nonpayable
```



*Transfers ownership of the contract to a new account (`newOwner`). Can only be called by the current owner.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| newOwner | address | undefined |

### trustedRemoteLookup

```solidity
function trustedRemoteLookup(uint16) external view returns (bytes)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes | undefined |

### unwrap

```solidity
function unwrap(address _toAddress, uint256 _amount) external nonpayable
```

Unwrap an ERC20 with a 1:1 ratio. Called only on main chain.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _toAddress | address | The address to unwrap the ERC20 to. |
| _amount | uint256 | The amount of ERC20 to unwrap. |

### wrap

```solidity
function wrap(address _toAddress, uint256 _amount) external nonpayable
```

Wrap an ERC20 with a 1:1 ratio with a fee if existing.

*Since it can be executed only on the main chain, if an address exists on the OP chain it will not allowed to wrap.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _toAddress | address | The address to wrap the ERC20 to. |
| _amount | uint256 | The amount of ERC20 to wrap. |



## Events

### Approval

```solidity
event Approval(address indexed owner, address indexed spender, uint256 value)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| owner `indexed` | address | undefined |
| spender `indexed` | address | undefined |
| value  | uint256 | undefined |

### Harvest

```solidity
event Harvest(uint256 _amount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _amount  | uint256 | undefined |

### MessageFailed

```solidity
event MessageFailed(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId  | uint16 | undefined |
| _srcAddress  | bytes | undefined |
| _nonce  | uint64 | undefined |
| _payload  | bytes | undefined |

### OwnershipTransferred

```solidity
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| previousOwner `indexed` | address | undefined |
| newOwner `indexed` | address | undefined |

### ReceiveFromChain

```solidity
event ReceiveFromChain(uint16 indexed _srcChainId, bytes indexed _srcAddress, address indexed _toAddress, uint256 _amount, uint64 _nonce)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId `indexed` | uint16 | undefined |
| _srcAddress `indexed` | bytes | undefined |
| _toAddress `indexed` | address | undefined |
| _amount  | uint256 | undefined |
| _nonce  | uint64 | undefined |

### SendToChain

```solidity
event SendToChain(address indexed _sender, uint16 indexed _dstChainId, bytes indexed _toAddress, uint256 _amount, uint64 _nonce)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _sender `indexed` | address | undefined |
| _dstChainId `indexed` | uint16 | undefined |
| _toAddress `indexed` | bytes | undefined |
| _amount  | uint256 | undefined |
| _nonce  | uint64 | undefined |

### SetTrustedRemote

```solidity
event SetTrustedRemote(uint16 _srcChainId, bytes _srcAddress)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId  | uint16 | undefined |
| _srcAddress  | bytes | undefined |

### Transfer

```solidity
event Transfer(address indexed from, address indexed to, uint256 value)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| from `indexed` | address | undefined |
| to `indexed` | address | undefined |
| value  | uint256 | undefined |

### Unwrap

```solidity
event Unwrap(address indexed _from, address indexed _to, uint256 _amount)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _from `indexed` | address | undefined |
| _to `indexed` | address | undefined |
| _amount  | uint256 | undefined |

### Wrap

```solidity
event Wrap(address indexed _from, address indexed _to, uint256 _amount)
```

========================== ========== Events ======== ==========================



#### Parameters

| Name | Type | Description |
|---|---|---|
| _from `indexed` | address | undefined |
| _to `indexed` | address | undefined |
| _amount  | uint256 | undefined |



## Errors

### TOFT__NotHostChain

```solidity
error TOFT__NotHostChain()
```

Code executed not on main chain (optimism/chainID mismatch).





