# Test Documentation for TapiocaZ Contracts

## Overview

This document outlines the testing coverage for the BaseTOFT (Base Tapioca Omnichain Fungible Token) contract. The BaseTOFT contract is part of a cross-chain token system, allowing for wrapping, unwrapping, and transfer of tokens across different blockchains.

## BaseTOFT Test Categories

### 1. Administrative Functions

- Test `setPause`:
  - Verify owner can pause and unpause the contract
  - Ensure non-owners cannot pause or unpause

### 2. Wrapping Functions

- Test `wrap_` function:
  - Successful wrapping with correct allowances and balances
  - Wrapping without proper allowance (should fail)
  - Wrapping with zero amount (should fail)

### 3. Unwrapping Functions

- Test `unwrap_` function:
  - Successful unwrapping with correct balance updates
  - Verify wrapped tokens are burned and original tokens are returned

### 4. Native Token Handling

- Note: Testing for `wrapNative_` is currently pending due to a known issue

## Test Cases

1. `test_setPause`: Verifies pause functionality and access control
2. `test_wrapSuccess`: Checks successful token wrapping
3. `test_wrapWithoutAllowance`: Ensures wrapping fails without proper allowance
4. `test_wrapWithZeroAmount`: Verifies wrapping with zero amount is rejected
5. `test_unwrapSuccess`: Tests successful unwrapping of tokens

## Helper Functions

- `setApprovals`: Sets up necessary approvals for testing
- `setTOFTData`: Prepares initialization data for BaseTOFT
- `setVaultOwnership`: Sets up vault ownership for testing

## Running the Tests

To run the tests, use the following command in the project root: `forge test --mc BaseTOFTTest`

## mTOFT Test Categories

### 1. Cross-Chain Token Transfer

- Test `send`: Verify successful token transfer across chains
- Test `sendPacket`: Ensure packet sending functionality works correctly
- Test `sendPacketFrom`: Check sending packets on behalf of other addresses

### 2. Wrapping and Unwrapping

- Test `wrap`: Verify token wrapping functionality
- Test `unwrap`: Ensure proper token unwrapping

### 3. Fee Handling

- Test wrap and unwrap fee calculations and registrations

### 4. Administrative Functions

- Test `setOwnerState`: Verify owner can update contract state
- Test `rescueEth`: Ensure owner can rescue ETH from the contract
- Test `withdrawFees`: Check fee withdrawal functionality

### 5. Access Control

- Verify only authorized addresses can perform certain actions

### 6. Integration with Other Components

- Test interaction with StargateRouter (`sgReceive`)
- Verify correct handling of LayerZero endpoints

## Test Cases

- `test_send_success`: Verifies successful cross-chain token sending
- `test_sendPacket_success`: Checks successful packet sending
- `test_sendPacketFrom_success`: Tests sending packets on behalf of others
- `test_sendPacketFrom_fail_Without_TOE_Role`: Ensures failure when sender lacks proper role
- `test_sendPacketFrom_fail_From_Zero_Address`: Verifies failure when sending from zero address
- `test_getTypedDataHash_deterministicOutput`: Checks consistency of typed data hash generation
- `test_wrap_success`: Verifies successful token wrapping
- `test_wrap_reverts_when_called_by_balancers`: Ensures balancers can't wrap tokens
- `test_wrap_reverts_when_chain_not_connected`: Checks failure when chain is not connected
- `test_wrap_reverts_invalid_cap`: Verifies cap limit enforcement
- `test_unwrap_success`: Tests successful token unwrapping
- `test_unwrap_reverts_when_called_by_balancers`: Ensures balancers can't unwrap tokens
- `test_unwrap_reverts_when_chain_not_connected`: Checks failure when chain is not connected
- `test_sgReceive_reverts_when_caller_is_not_stargateRouter`: Verifies access control for `sgReceive`
- `test_sgReceive_caller_is_stargateRouter`: Checks successful `sgReceive` operation
- `test_rescueEth_reverts_when_not_owner`: Ensures only owner can rescue ETH
- `test_rescueEth_success`: Verifies successful ETH rescue by owner
- `test_setOwnerState_reverts_when_not_owner`: Checks owner-only access for state changes
- `test_setOwnerState_reverts_when_new_mintCap_less_than_totalSupply`: Verifies mint cap validation
- `test_withdrawFees_success`: Checks successful fee withdrawal
- `test_withdrawFees_reverts_when_not_owner`: Ensures only owner can withdraw fees
- `test_extractUnderlying_revert_when_not_balancer`: Verifies access control for extracting underlying assets
- `test_extractUnderlying_reverts_zero_amount`: Checks failure on zero amount extraction
- `test_extractUnderlying_success`: Verifies successful underlying asset extraction
- `test_wrap_fees_are_correctly_registred`: Ensures proper fee registration during wrapping
- `test_unwrap_fees_are_correctly_registered`: Verifies correct fee handling during unwrapping

## Helper Functions

- `setOwnerState`: Sets up owner state for testing
- `getLzParams`: Prepares LayerZero parameters for cross-chain operations
- `setApprovals`: Sets necessary approvals for token operations
- `initTOFTData`: Initializes TOFT data for testing

## Running the Tests

To run the tests, use the following command in the project root: `forge test --mc mTOFTTest`

## ModuleManager Test Categories

### 1. Module Setting

- Test `setModule_` function:
  - Verify module can be set with correct address
  - Ensure module address is correctly retrievable after setting

### 2. Module Extraction

- Test `extractModule_` function:
  - Successful extraction of a set module
  - Extraction of an unset module (should fail)

### 3. Module Execution

- Test `executeModule_` function:
  - Successful execution of a set module
  - Execution of an unset module (should fail)

### 4. Access Control

- Verify only authorized modules can be extracted and executed

## Test Cases

- `test_set_module`: Verifies module setting functionality
- `test_extract_module_sucess`: Checks successful extraction of a set module
- `test_extract_module_not_authorized`: Ensures extraction fails for an unset module
- `test_execute_module_not_authorized`: Verifies execution fails for an unset module
- `test_execute_module_sucess`: Tests successful execution of a set module

## Helper Functions

- `whiteListedModule`: Retrieves the address of a whitelisted module

## Running the Tests

To run the tests, use the following command in the project root: `forge test --mc ModuleManagerTest`

## TOFTGenericReceiverModule Test Categories

### 1. Receive With Params

Test receiveWithParamsReceiver: Verify successful token receiving and unwrapping
Test error handling for amount mismatch

### 2. Unwrapping and Transfer

Test unwrapping of tokens and transfer to the receiver
Verify correct balance updates in the vault and receiver's account

## Test Cases

`test_receiveWithParamsReceiver_unwrapAndTransfer_success`:

Verifies successful receiving, unwrapping, and transfer of tokens
Checks correct balance updates in the vault and receiver's account

`test_receiveWithParamsReceiver_transfer_fail_amountMismatch`: Ensures the function reverts when there's a mismatch in the amount

## Helper Functions

`toLD`: Converts amounts to the correct decimals (used internally)

## Running the Tests

To run the tests, use the following command in the project root:
Copyforge test --mc TOFTGenericReceiverModuleTest

## Notes

-The tests use a mock version of the TOFTGenericReceiverModule for testing purposes
-The tests cover both successful scenarios and error cases
-Token minting is simulated using the OFT mint function for testing purposes
