.PHONY: deploy-testnet deploy-mainnet

deploy-testnet:
    source .env && forge script script/Deploy.s.sol:DeployScript --rpc-url $$OPTIMISM_SEPOLIA_RPC --broadcast --verify -vvvv

deploy-mainnet:
    source .env && forge script script/Deploy.s.sol:DeployScript --rpc-url $$OPTIMISM_MAINNET_RPC --broadcast --verify -vvvv