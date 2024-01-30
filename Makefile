.PHONY: dipslayBalances deploy hardhatCompile buildNightlySDK
all: hardhatCompile deploy


# Networks to deploy to
NETWORKS = arbitrum_sepolia optimism_sepolia 

BALANCE_OF_COMMAND = hh utils balanceOf
dipslayBalances:
	@echo "Displaying balances for " && hh utils currentAccount --network arbitrum_sepolia
	@$(foreach var,$(NETWORKS), echo "${var}": && $(BALANCE_OF_COMMAND)  --network $(var) ; )

DEPLOY_STACK_COMMAND = hh deploys stack 
deploy:
	@$(foreach var,$(NETWORKS), echo "Deploying to ${var}": && $(DEPLOY_STACK_COMMAND) --network $(var) ; )
	
#TODO: update deploy task

hardhatCompile:
	@hh compile --network localhost

buildNightlySDK:
	@cd lib/tapioca-sdk && yarn build