.PHONY: dipslayBalances hardhatCompile buildNightlySDK
all: hardhatCompile


# Networks to deploy to
NETWORKS = arbitrum_sepolia optimism_sepolia 

BALANCE_OF_COMMAND = hh utils balanceOf
dipslayBalances:
	@echo "Displaying balances for " && hh utils currentAccount --network arbitrum_sepolia
	@$(foreach var,$(NETWORKS), echo "${var}": && $(BALANCE_OF_COMMAND)  --network $(var) ; )

#DEPLOY_STACK_COMMAND = hh deploys stack 
#deploy:
#	@$(foreach var,$(NETWORKS), echo "Deploying to ${var}": && $(DEPLOY_STACK_COMMAND) --network $(var) ; )

hardhatCompile:
	@hh compile --network localhost

buildNightlySDK:
	@cd gitmodule/tapioca-sdk && yarn build