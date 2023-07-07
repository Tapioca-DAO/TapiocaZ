# TapiocaOFT









## Methods

### DEFAULT_PAYLOAD_SIZE_LIMIT

```solidity
function DEFAULT_PAYLOAD_SIZE_LIMIT() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### DOMAIN_SEPARATOR

```solidity
function DOMAIN_SEPARATOR() external view returns (bytes32)
```



*See {IERC20Permit-DOMAIN_SEPARATOR}.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes32 | undefined |

### NO_EXTRA_GAS

```solidity
function NO_EXTRA_GAS() external view returns (uint256)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### PT_SEND

```solidity
function PT_SEND() external view returns (uint8)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | undefined |

### PT_SEND_AND_CALL

```solidity
function PT_SEND_AND_CALL() external view returns (uint8)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | undefined |

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

### callOnOFTReceived

```solidity
function callOnOFTReceived(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes32 _from, address _to, uint256 _amount, bytes _payload, uint256 _gasForCall) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _srcAddress | bytes | undefined |
| _nonce | uint64 | undefined |
| _from | bytes32 | undefined |
| _to | address | undefined |
| _amount | uint256 | undefined |
| _payload | bytes | undefined |
| _gasForCall | uint256 | undefined |

### circulatingSupply

```solidity
function circulatingSupply() external view returns (uint256)
```



*returns the circulating amount of tokens on current chain*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

### creditedPackets

```solidity
function creditedPackets(uint16, bytes, uint64) external view returns (bool)
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
| _0 | bool | undefined |

### decimals

```solidity
function decimals() external view returns (uint8)
```

decimal number of the ERC20




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
function erc20() external view returns (address)
```

The ERC20 to wrap.




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### estimateSendAndCallFee

```solidity
function estimateSendAndCallFee(uint16 _dstChainId, bytes32 _toAddress, uint256 _amount, bytes _payload, uint64 _dstGasForCall, bool _useZro, bytes _adapterParams) external view returns (uint256 nativeFee, uint256 zroFee)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId | uint16 | undefined |
| _toAddress | bytes32 | undefined |
| _amount | uint256 | undefined |
| _payload | bytes | undefined |
| _dstGasForCall | uint64 | undefined |
| _useZro | bool | undefined |
| _adapterParams | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| nativeFee | uint256 | undefined |
| zroFee | uint256 | undefined |

### estimateSendFee

```solidity
function estimateSendFee(uint16 _dstChainId, bytes32 _toAddress, uint256 _amount, bool _useZro, bytes _adapterParams) external view returns (uint256 nativeFee, uint256 zroFee)
```



*estimate send token `_tokenId` to (`_dstChainId`, `_toAddress`) _dstChainId - L0 defined chain id to send tokens too _toAddress - dynamic bytes array which contains the address to whom you are sending tokens to on the dstChain _amount - amount of the tokens to transfer _useZro - indicates to use zro to pay L0 fees _adapterParam - flexible bytes array to indicate messaging adapter services in L0*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId | uint16 | undefined |
| _toAddress | bytes32 | undefined |
| _amount | uint256 | undefined |
| _useZro | bool | undefined |
| _adapterParams | bytes | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| nativeFee | uint256 | undefined |
| zroFee | uint256 | undefined |

### exerciseOption

```solidity
function exerciseOption(ITapiocaOptionsBrokerCrossChain.IExerciseOptionsData optionsData, ITapiocaOptionsBrokerCrossChain.IExerciseLZData lzData, ITapiocaOptionsBrokerCrossChain.IExerciseLZSendTapData tapSendData, ICommonData.IApproval[] approvals) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| optionsData | ITapiocaOptionsBrokerCrossChain.IExerciseOptionsData | undefined |
| lzData | ITapiocaOptionsBrokerCrossChain.IExerciseLZData | undefined |
| tapSendData | ITapiocaOptionsBrokerCrossChain.IExerciseLZSendTapData | undefined |
| approvals | ICommonData.IApproval[] | undefined |

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

### getTrustedRemoteAddress

```solidity
function getTrustedRemoteAddress(uint16 _remoteChainId) external view returns (bytes)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _remoteChainId | uint16 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bytes | undefined |

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

### initMultiSell

```solidity
function initMultiSell(address from, uint256 share, IUSDOBase.ILeverageSwapData swapData, IUSDOBase.ILeverageLZData lzData, IUSDOBase.ILeverageExternalContractsData externalData, bytes airdropAdapterParams, ICommonData.IApproval[] approvals) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| from | address | undefined |
| share | uint256 | undefined |
| swapData | IUSDOBase.ILeverageSwapData | undefined |
| lzData | IUSDOBase.ILeverageLZData | undefined |
| externalData | IUSDOBase.ILeverageExternalContractsData | undefined |
| airdropAdapterParams | bytes | undefined |
| approvals | ICommonData.IApproval[] | undefined |

### isLdChain

```solidity
function isLdChain(uint16) external view returns (bool)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |

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

### leverageModule

```solidity
function leverageModule() external view returns (contract BaseTOFTLeverageModule)
```

returns the leverage module




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract BaseTOFTLeverageModule | undefined |

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

### marketModule

```solidity
function marketModule() external view returns (contract BaseTOFTMarketModule)
```

returns the Market module




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract BaseTOFTMarketModule | undefined |

### minDstGasLookup

```solidity
function minDstGasLookup(uint16, uint16) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |
| _1 | uint16 | undefined |

#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint256 | undefined |

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

### optionsModule

```solidity
function optionsModule() external view returns (contract BaseTOFTOptionsModule)
```

returns the Options module




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract BaseTOFTOptionsModule | undefined |

### owner

```solidity
function owner() external view returns (address)
```



*Returns the address of the current owner.*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### payloadSizeLimitLookup

```solidity
function payloadSizeLimitLookup(uint16) external view returns (uint256)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _0 | uint16 | undefined |

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

### precrime

```solidity
function precrime() external view returns (address)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

### removeCollateral

```solidity
function removeCollateral(address from, address to, uint16 lzDstChainId, address zroPaymentAddress, ICommonData.IWithdrawParams withdrawParams, ITapiocaOFT.IRemoveParams removeParams, ICommonData.IApproval[] approvals, bytes adapterParams) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| from | address | undefined |
| to | address | undefined |
| lzDstChainId | uint16 | undefined |
| zroPaymentAddress | address | undefined |
| withdrawParams | ICommonData.IWithdrawParams | undefined |
| removeParams | ITapiocaOFT.IRemoveParams | undefined |
| approvals | ICommonData.IApproval[] | undefined |
| adapterParams | bytes | undefined |

### renounceOwnership

```solidity
function renounceOwnership() external nonpayable
```



*Leaves the contract without owner. It will not be possible to call `onlyOwner` functions anymore. Can only be called by the current owner. NOTE: Renouncing ownership will leave the contract without an owner, thereby removing any functionality that is only available to the owner.*


### retrieveFromStrategy

```solidity
function retrieveFromStrategy(address from, uint256 amount, uint256 share, uint256 assetId, uint16 lzDstChainId, address zroPaymentAddress, bytes airdropAdapterParam) external payable
```

extracts TOFT from a specific strategy available on another layer



#### Parameters

| Name | Type | Description |
|---|---|---|
| from | address | the sender address |
| amount | uint256 | the transferred amount |
| share | uint256 | undefined |
| assetId | uint256 | the destination YieldBox asset id |
| lzDstChainId | uint16 | the destination LayerZero id |
| zroPaymentAddress | address | LayerZero ZRO payment address |
| airdropAdapterParam | bytes | the LayerZero aidrop adapter params |

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

### sendAndCall

```solidity
function sendAndCall(address _from, uint16 _dstChainId, bytes32 _toAddress, uint256 _amount, bytes _payload, uint64 _dstGasForCall, ICommonOFT.LzCallParams _callParams) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _from | address | undefined |
| _dstChainId | uint16 | undefined |
| _toAddress | bytes32 | undefined |
| _amount | uint256 | undefined |
| _payload | bytes | undefined |
| _dstGasForCall | uint64 | undefined |
| _callParams | ICommonOFT.LzCallParams | undefined |

### sendForLeverage

```solidity
function sendForLeverage(uint256 amount, address leverageFor, IUSDOBase.ILeverageLZData lzData, IUSDOBase.ILeverageSwapData swapData, IUSDOBase.ILeverageExternalContractsData externalData) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| amount | uint256 | undefined |
| leverageFor | address | undefined |
| lzData | IUSDOBase.ILeverageLZData | undefined |
| swapData | IUSDOBase.ILeverageSwapData | undefined |
| externalData | IUSDOBase.ILeverageExternalContractsData | undefined |

### sendFrom

```solidity
function sendFrom(address _from, uint16 _dstChainId, bytes32 _toAddress, uint256 _amount, ICommonOFT.LzCallParams _callParams) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _from | address | undefined |
| _dstChainId | uint16 | undefined |
| _toAddress | bytes32 | undefined |
| _amount | uint256 | undefined |
| _callParams | ICommonOFT.LzCallParams | undefined |

### sendToStrategy

```solidity
function sendToStrategy(address from, address to, uint256 amount, uint256 share, uint256 assetId, uint16 lzDstChainId, ICommonData.ISendOptions options) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| from | address | undefined |
| to | address | undefined |
| amount | uint256 | undefined |
| share | uint256 | undefined |
| assetId | uint256 | undefined |
| lzDstChainId | uint16 | undefined |
| options | ICommonData.ISendOptions | undefined |

### sendToYBAndBorrow

```solidity
function sendToYBAndBorrow(address from, address to, uint16 lzDstChainId, bytes airdropAdapterParams, ITapiocaOFT.IBorrowParams borrowParams, ICommonData.IWithdrawParams withdrawParams, ICommonData.ISendOptions options, ICommonData.IApproval[] approvals) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| from | address | undefined |
| to | address | undefined |
| lzDstChainId | uint16 | undefined |
| airdropAdapterParams | bytes | undefined |
| borrowParams | ITapiocaOFT.IBorrowParams | undefined |
| withdrawParams | ICommonData.IWithdrawParams | undefined |
| options | ICommonData.ISendOptions | undefined |
| approvals | ICommonData.IApproval[] | undefined |

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

### setLdChain

```solidity
function setLdChain(uint16 _chainId, bool _isLdChain) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _chainId | uint16 | undefined |
| _isLdChain | bool | undefined |

### setMinDstGas

```solidity
function setMinDstGas(uint16 _dstChainId, uint16 _packetType, uint256 _minGas) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId | uint16 | undefined |
| _packetType | uint16 | undefined |
| _minGas | uint256 | undefined |

### setPayloadSizeLimit

```solidity
function setPayloadSizeLimit(uint16 _dstChainId, uint256 _size) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId | uint16 | undefined |
| _size | uint256 | undefined |

### setPrecrime

```solidity
function setPrecrime(address _precrime) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _precrime | address | undefined |

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
function setTrustedRemote(uint16 _srcChainId, bytes _path) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId | uint16 | undefined |
| _path | bytes | undefined |

### setTrustedRemoteAddress

```solidity
function setTrustedRemoteAddress(uint16 _remoteChainId, bytes _remoteAddress) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _remoteChainId | uint16 | undefined |
| _remoteAddress | bytes | undefined |

### setUseCustomAdapterParams

```solidity
function setUseCustomAdapterParams(bool _useCustomAdapterParams) external nonpayable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _useCustomAdapterParams | bool | undefined |

### sharedDecimals

```solidity
function sharedDecimals() external view returns (uint8)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | uint8 | undefined |

### strategyModule

```solidity
function strategyModule() external view returns (contract BaseTOFTStrategyModule)
```

returns the Strategy module




#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | contract BaseTOFTStrategyModule | undefined |

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

### token

```solidity
function token() external view returns (address)
```



*returns the address of the ERC20 token*


#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | address | undefined |

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

### triggerSendFrom

```solidity
function triggerSendFrom(uint16 lzDstChainId, bytes airdropAdapterParams, address zroPaymentAddress, uint256 amount, ISendFrom.LzCallParams sendFromData, ICommonData.IApproval[] approvals) external payable
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| lzDstChainId | uint16 | undefined |
| airdropAdapterParams | bytes | undefined |
| zroPaymentAddress | address | undefined |
| amount | uint256 | undefined |
| sendFromData | ISendFrom.LzCallParams | undefined |
| approvals | ICommonData.IApproval[] | undefined |

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

Unwrap an ERC20/Native with a 1:1 ratio. Called only on host chain.



#### Parameters

| Name | Type | Description |
|---|---|---|
| _toAddress | address | The address to unwrap the tokens to. |
| _amount | uint256 | The amount of tokens to unwrap. |

### useCustomAdapterParams

```solidity
function useCustomAdapterParams() external view returns (bool)
```






#### Returns

| Name | Type | Description |
|---|---|---|
| _0 | bool | undefined |

### wrap

```solidity
function wrap(address _fromAddress, address _toAddress, uint256 _amount) external payable
```

Wrap an ERC20 with a 1:1 ratio with a fee if existing.

*Since it can be executed only on the main chain, if an address exists on the OP chain it will not allowed to wrap.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _fromAddress | address | The address to wrap from. |
| _toAddress | address | The address to wrap the ERC20 to. |
| _amount | uint256 | The amount of ERC20 to wrap. |

### yieldBox

```solidity
function yieldBox() external view returns (contract IYieldBoxBase)
```

The YieldBox address.




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

### CallOFTReceivedSuccess

```solidity
event CallOFTReceivedSuccess(uint16 indexed _srcChainId, bytes _srcAddress, uint64 _nonce, bytes32 _hash)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId `indexed` | uint16 | undefined |
| _srcAddress  | bytes | undefined |
| _nonce  | uint64 | undefined |
| _hash  | bytes32 | undefined |

### MessageFailed

```solidity
event MessageFailed(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes _payload, bytes _reason)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId  | uint16 | undefined |
| _srcAddress  | bytes | undefined |
| _nonce  | uint64 | undefined |
| _payload  | bytes | undefined |
| _reason  | bytes | undefined |

### NonContractAddress

```solidity
event NonContractAddress(address _address)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _address  | address | undefined |

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
event ReceiveFromChain(uint16 indexed _srcChainId, address indexed _to, uint256 _amount)
```



*Emitted when `_amount` tokens are received from `_srcChainId` into the `_toAddress` on the local chain. `_nonce` is the inbound nonce.*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId `indexed` | uint16 | undefined |
| _to `indexed` | address | undefined |
| _amount  | uint256 | undefined |

### RetryMessageSuccess

```solidity
event RetryMessageSuccess(uint16 _srcChainId, bytes _srcAddress, uint64 _nonce, bytes32 _payloadHash)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _srcChainId  | uint16 | undefined |
| _srcAddress  | bytes | undefined |
| _nonce  | uint64 | undefined |
| _payloadHash  | bytes32 | undefined |

### SendToChain

```solidity
event SendToChain(uint16 indexed _dstChainId, address indexed _from, bytes32 indexed _toAddress, uint256 _amount)
```



*Emitted when `_amount` tokens are moved from the `_sender` to (`_dstChainId`, `_toAddress`) `_nonce` is the outbound nonce*

#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId `indexed` | uint16 | undefined |
| _from `indexed` | address | undefined |
| _toAddress `indexed` | bytes32 | undefined |
| _amount  | uint256 | undefined |

### SetMinDstGas

```solidity
event SetMinDstGas(uint16 _dstChainId, uint16 _type, uint256 _minDstGas)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _dstChainId  | uint16 | undefined |
| _type  | uint16 | undefined |
| _minDstGas  | uint256 | undefined |

### SetPrecrime

```solidity
event SetPrecrime(address precrime)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| precrime  | address | undefined |

### SetTrustedRemote

```solidity
event SetTrustedRemote(uint16 _remoteChainId, bytes _path)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _remoteChainId  | uint16 | undefined |
| _path  | bytes | undefined |

### SetTrustedRemoteAddress

```solidity
event SetTrustedRemoteAddress(uint16 _remoteChainId, bytes _remoteAddress)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _remoteChainId  | uint16 | undefined |
| _remoteAddress  | bytes | undefined |

### SetUseCustomAdapterParams

```solidity
event SetUseCustomAdapterParams(bool _useCustomAdapterParams)
```





#### Parameters

| Name | Type | Description |
|---|---|---|
| _useCustomAdapterParams  | bool | undefined |

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



