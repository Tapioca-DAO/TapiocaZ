# TapiocaOFT









## Methods

### DOMAIN_SEPARATOR

```solidity
function DOMAIN_SEPARATOR() external view returns (bytes32)
```



*See {IERC20Permit-DOMAIN_SEPARATOR}.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### PT_YB_RETRIEVE_STRAT

```solidity
function PT_YB_RETRIEVE_STRAT() external view returns (uint16)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |

### PT_YB_SEND_SGL_BORROW

```solidity
function PT_YB_SEND_SGL_BORROW() external view returns (uint16)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |

### PT_YB_SEND_STRAT

```solidity
function PT_YB_SEND_STRAT() external view returns (uint16)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |

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

### decimals

```solidity
function decimals() external view returns (uint8)
```



*Returns the number of decimals used to get its user representation. For example, if `decimals` equals `2`, a balance of `505` tokens should be displayed to a user as `5.05` (`505 / 10 ** 2`). Tokens usually opt for a value of 18, imitating the relationship between Ether and Wei. This is the value {ERC20} uses, unless this function is overridden; NOTE: This information is only used for _display_ purposes: it in no way affects any of the arithmetic of the contract, including {IERC20-balanceOf} and {IERC20-transfer}.*


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

### hostChainID

```solidity
function hostChainID() external view returns (uint256)
```

The host chain ID of the ERC20




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

Check if the current chain is the host chain of the ERC20.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### isNative

```solidity
function isNative() external view returns (bool)
```

If this wrapper is for an ERC20 or a native token.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### name

```solidity
function name() external view returns (string)
```



*Returns the name of the token.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### nonces

```solidity
function nonces(address owner) external view returns (uint256)
```



*See {IERC20Permit-nonces}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner | address | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### permit

```solidity
function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external nonpayable
```



*See {IERC20Permit-permit}.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner | address | undefined |
| spender | address | undefined |
| value | uint256 | undefined |
| deadline | uint256 | undefined |
| v | uint8 | undefined |
| r | bytes32 | undefined |
| s | bytes32 | undefined |

### sendToYBAndBorrow

```solidity
function sendToYBAndBorrow(address _from, address _to, uint16 lzDstChainId, bytes airdropAdapterParams, tOFTCommon.IBorrowParams borrowParams, tOFTCommon.IWithdrawParams withdrawParams, tOFTCommon.SendOptions options, tOFTCommon.IApproval[] approvals) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _from | address | undefined |
| _to | address | undefined |
| lzDstChainId | uint16 | undefined |
| airdropAdapterParams | bytes | undefined |
| borrowParams | tOFTCommon.IBorrowParams | undefined |
| withdrawParams | tOFTCommon.IWithdrawParams | undefined |
| options | tOFTCommon.SendOptions | undefined |
| approvals | tOFTCommon.IApproval[] | undefined |

### symbol

```solidity
function symbol() external view returns (string)
```



*Returns the symbol of the token, usually a shorter version of the name.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | string | undefined |

### tOFTMarketModule

```solidity
function tOFTMarketModule() external view returns (contract tOFTMarket)
```

returns the market module




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract tOFTMarket | undefined |

### tapiocaWrapper

```solidity
function tapiocaWrapper() external view returns (contract TapiocaWrapper)
```

The TapiocaWrapper contract, owner of this contract.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract TapiocaWrapper | undefined |

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

### unwrap

```solidity
function unwrap(address _toAddress, uint256 _amount) external nonpayable
```

Unwrap an ERC20/Native with a 1:1 ratio. Called only on host chain.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _toAddress | address | The address to unwrap the tokens to. |
| _amount | uint256 | The amount of tokens to unwrap. |

### wrap

```solidity
function wrap(address _fromAddress, address _toAddress, uint256 _amount) external nonpayable
```

Wrap an ERC20 with a 1:1 ratio with a fee if existing.

*Since it can be executed only on the main chain, if an address exists on the OP chain it will not allowed to wrap.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _fromAddress | address | undefined |
| _toAddress | address | The address to wrap the ERC20 to. |
| _amount | uint256 | The amount of ERC20 to wrap. |

### wrapNative

```solidity
function wrapNative(address _toAddress) external payable
```

Wrap a native token with a 1:1 ratio with a fee if existing.

*Since it can be executed only on the host chain, if an address exists on the linked chain it will not allowed to wrap.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _toAddress | address | The address to wrap the tokens to. |

### yieldBox

```solidity
function yieldBox() external view returns (contract IYieldBoxBase)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract IYieldBoxBase | undefined |



## Events

### Approval

```solidity
event Approval(address indexed owner, address indexed spender, uint256 value)
```



*Emitted when the allowance of a `spender` for an `owner` is set by a call to {approve}. `value` is the new allowance.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| owner `indexed` | address | undefined |
| spender `indexed` | address | undefined |
| value  | uint256 | undefined |

### Transfer

```solidity
event Transfer(address indexed from, address indexed to, uint256 value)
```



*Emitted when `value` tokens are moved from one account (`from`) to another (`to`). Note that `value` may be zero.*

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

event emitted when an unwrap operation is performed



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

event emitted when a wrap operation is performed



#### Parameters

| Name | Type | Description |
|---|---|---|
| _from `indexed` | address | undefined |
| _to `indexed` | address | undefined |
| _amount  | uint256 | undefined |

### YieldBoxDeposit

```solidity
event YieldBoxDeposit(uint256 _amount)
```

event emitted when a YieldBox deposit is done



#### Parameters

| Name | Type | Description |
|---|---|---|
| _amount  | uint256 | undefined |

### YieldBoxRetrieval

```solidity
event YieldBoxRetrieval(uint256 _amount)
```

event emitted when YieldBox funds are removed



#### Parameters

| Name | Type | Description |
|---|---|---|
| _amount  | uint256 | undefined |



