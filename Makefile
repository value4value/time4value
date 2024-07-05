SHELL := /bin/bash
.PHONY: deploy-testnet deploy-mainnet deploy-aave-mainnet

DEPLOY_CMD=source .env && forge script scripts/Deploy.s.sol:DeployScript
DEPLOY_AAVE_CMD=source .env && forge script scripts/DeployAave.s.sol:DeployAaveScript
VERIFY_CMD=--etherscan-api-key $$OPTIMISM_ETHERSCAN_API_KEY --verify

deploy-testnet:
	${DEPLOY_CMD} --rpc-url $$OPTIMISM_TESTNET_RPC --broadcast ${VERIFY_CMD} -vvvv
	#${DEPLOY_CMD} --rpc-url $$CYBER_TESTNET_RPC --broadcast -vvvv

deploy-mainnet:
	${DEPLOY_CMD} --rpc-url $$OPTIMISM_MAINNET_RPC --broadcast ${VERIFY_CMD} -vvvv
	#${DEPLOY_CMD} --rpc-url $$CYBER_MAINNET_RPC --broadcast -vvvv

deploy-aave-testnet:
	${DEPLOY_AAVE_CMD} --rpc-url $$OPTIMISM_TESTNET_RPC --broadcast ${VERIFY_CMD} -vvvv

deploy-aave-mainnet:
	${DEPLOY_AAVE_CMD} --rpc-url $$OPTIMISM_MAINNET_RPC --broadcast ${VERIFY_CMD} -vvvv
