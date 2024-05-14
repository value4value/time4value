#!/bin/bash

# run from top level:mest-protocol

# receive command line parameter, setting network name
# use: ./deploy/deploy.sh optimism-sepolia
NETWORK_NAME=$1

OUTPUT_JSON="./deploy/deployed_addresses.json"

RPC_URL=$(jq -r --arg net "$NETWORK_NAME" '.[$net].rpcUrl' ./deploy/config.json) 
MEST_BASE_URL=$(jq -r --arg net "$NETWORK_NAME" '.[$net].mestBaseUrl' ./deploy/config.json)
WETH=$(jq -r --arg net "$NETWORK_NAME" '.[$net].weth' ./deploy/config.json)
SCAN_URL=$(jq -r --arg net "$NETWORK_NAME" '.[$net].scanUrl' ./deploy/config.json)
AAVE_POOL=$(jq -r --arg net "$NETWORK_NAME" '.[$net].aavePool' ./deploy/config.json)
AAVE_GATEWAY=$(jq -r --arg net "$NETWORK_NAME" '.[$net].aaveGateWay' ./deploy/config.json)

# curve setting
BASE_PRICE=$(jq -r --arg net "$NETWORK_NAME" '.[$net].curveSetting.basePrice' ./deploy/config.json)
INFLECTION_POINT=$(jq -r --arg net "$NETWORK_NAME" '.[$net].curveSetting.inflectionPoint' ./deploy/config.json)
INFLECTION_PRICE=$(jq -r --arg net "$NETWORK_NAME" '.[$net].curveSetting.inflectionPrice' ./deploy/config.json)
LINEAR_PRICE_SLOPE=$(jq -r --arg net "$NETWORK_NAME" '.[$net].curveSetting.linearPriceSlope' ./deploy/config.json)

# deploy mestERC1155
MESTERC1155_ADDRESS=$(forge create contracts/core/MestERC1155.sol:MestERC1155  \
    --rpc-url $RPC_URL  \
    --private-key $PRIVATE_KEY \
    --constructor-args $MEST_BASE_URL \
    --etherscan-api-key $API_KEY \
    --verifier-url $SCAN_URL \
    --json | jq -r '.deployedTo')
echo "MestERC1155 deployed at address: $MESTERC1155_ADDRESS"
echo "Using RPC URL: $RPC_URL"

# deploy mestFactory
MESTFACTORY_ADDRESS=$(forge create contracts/core/MestSharesFactoryV1.sol:MestSharesFactoryV1 \
    --constructor-args $MESTERC1155_ADDRESS $BASE_PRICE $INFLECTION_POINT $INFLECTION_PRICE $LINEAR_PRICE_SLOPE\
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --etherscan-api-key $API_KEY \
    --verifier-url $SCAN_URL \
    --json | jq -r '.deployedTo')
echo "MestFactory deployed at address: $MESTFACTORY_ADDRESS"
echo "Using RPC URL: $RPC_URL"

# deploy aave yieldAggregator
AAVE_YIELDAGGREGATOR_ADDRESS=$(forge create contracts/core/aggregator/AaveYieldAggregator.sol:AaveYieldAggregator \
    --constructor-args $MESTFACTORY_ADDRESS $WETH $AAVE_POOL $AAVE_GATEWAY \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --etherscan-api-key $API_KEY \
    --verifier-url $SCAN_URL \
    --json | jq -r '.deployedTo')
echo "Aave YieldAggregator deployed at address: $AAVE_YIELDAGGREGATOR_ADDRESS"
echo "Using RPC URL: $RPC_URL"

# deploy blank yieldAggregator
BLANK_YIELDAGGREGATOR_ADDRESS=$(forge create contracts/core/aggregator/BlankYieldAggregator.sol:BlankYieldAggregator \
    --constructor-args $MESTFACTORY_ADDRESS $WETH \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --etherscan-api-key $API_KEY \
    --verifier-url $SCAN_URL \
    --json | jq -r '.deployedTo')
echo "Blank YieldAggregator deployed at address: $BLANK_YIELDAGGREGATOR_ADDRESS"
echo "Using RPC URL: $RPC_URL"

# record address
echo "{
    \"$NETWORK_NAME\" : {
        \"MestERC1155\": \"$MESTERC1155_ADDRESS\", 
        \"MestFactory\": \"$MESTFACTORY_ADDRESS\", 
        \"YieldAggregator For Aave\": \"$AAVE_YIELDAGGREGATOR_ADDRESS\", 
        \"YieldAggregator For Blank\": \"$BLANK_YIELDAGGREGATOR_ADDRESS\"
    }
}" > $OUTPUT_JSON

# set factory for 1155
cast send $MESTERC1155_ADDRESS "setFactory(address)" $MESTFACTORY_ADDRESS --rpc-url $RPC_URL --private-key $PRIVATE_KEY
echo "Erc1155 set factory: $MESTFACTORY_ADDRESS"

# set yieldTool for factory
cast send $MESTFACTORY_ADDRESS "migrate(address)" $AAVE_YIELDAGGREGATOR_ADDRESS --rpc-url $RPC_URL --private-key $PRIVATE_KEY
echo "Factory set yield tool: $AAVE_YIELDAGGREGATOR_ADDRESS"

# verify, if verifier in create didn't work.
forge verify-contract \
    --verifier-url $SCAN_URL \
    --watch \
    --constructor-args $(cast abi-encode "constructor(string)"  $MEST_BASE_URL) \
    --etherscan-api-key $API_KEY \
    $MESTERC1155_ADDRESS \
    contracts/core/MestERC1155.sol:MestERC1155 

forge verify-contract \
    --verifier-url $SCAN_URL \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address,uint256,uint256,uint256,uint256)"  $MESTERC1155_ADDRESS $BASE_PRICE $INFLECTION_POINT $INFLECTION_PRICE $LINEAR_PRICE_SLOPE) \
    --etherscan-api-key $API_KEY \
    $MESTFACTORY_ADDRESS \
    contracts/core/MestSharesFactoryV1.sol:MestSharesFactoryV1

forge verify-contract \
    --verifier-url $SCAN_URL \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address,address,address,address)"  $MESTFACTORY_ADDRESS $WETH $AAVE_POOL $AAVE_GATEWAY) \
    --etherscan-api-key $API_KEY \
    $AAVE_YIELDAGGREGATOR_ADDRESS \
    contracts/core/aggregator/AaveYieldAggregator.sol:AaveYieldAggregator 
    
forge verify-contract \
    --verifier-url $SCAN_URL \
    --watch \
    --constructor-args $(cast abi-encode "constructor(address,address)"  $MESTFACTORY_ADDRESS $WETH) \
    --etherscan-api-key $API_KEY \
    $BLANK_YIELDAGGREGATOR_ADDRESS \
    contracts/core/aggregator/BlankYieldAggregator.sol:BlankYieldAggregator