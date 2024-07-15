SHELL := /bin/bash
.PHONY: deploy-core-optimism-sepolia deploy-aave-optimism-sepolia deploy-core-optimism deploy-aave-optimism deploy-core-cyber-testnet deploy-aave-cyber-testnet deploy-core-cyber deploy-aave-cyber

DEPLOY_CMD=source .env && forge script scripts/DeployCore.s.sol:DeployCoreScript
DEPLOY_AAVE_CMD=source .env && forge script scripts/DeployAave.s.sol:DeployAaveScript
VERIFY_CMD=--etherscan-api-key $$OPTIMISM_ETHERSCAN_API_KEY --verify


## network: optimism-sepolia
deploy-core-optimism-sepolia:
	${DEPLOY_CMD} --rpc-url $$OPTIMISM_TESTNET_RPC --broadcast ${VERIFY_CMD} -vvvv

deploy-aave-optimism-sepolia:
	${DEPLOY_AAVE_CMD} --rpc-url $$OPTIMISM_TESTNET_RPC --broadcast ${VERIFY_CMD} -vvvv

## network: optimism
deploy-core-optimism:
	${DEPLOY_CMD} --rpc-url $$OPTIMISM_MAINNET_RPC --broadcast ${VERIFY_CMD} -vvvv

deploy-aave-optimism:
	${DEPLOY_AAVE_CMD} --rpc-url $$OPTIMISM_MAINNET_RPC --broadcast ${VERIFY_CMD} -vvvv

## network: cyber-testnet
deploy-core-cyber-testnet:
	${DEPLOY_CMD} --rpc-url $$CYBER_TESTNET_RPC --broadcast ${VERIFY_CMD} -vvvv

deploy-aave-cyber-testnet:
	${DEPLOY_AAVE_CMD} --rpc-url $$CYBER_TESTNET_RPC --broadcast ${VERIFY_CMD} -vvvv

## network: cyber-mainnet
deploy-core-cyber:
	${DEPLOY_CMD} --rpc-url $$CYBER_MAINNET_RPC --broadcast ${VERIFY_CMD} -vvvv

deploy-aave-cyber:
	${DEPLOY_AAVE_CMD} --rpc-url $$CYBER_MAINNET_RPC --broadcast ${VERIFY_CMD} -vvvv