include .env
export

.PHONY: all test deploy-sepolia

all: test deploy-sepolia

test:
	@forge fmt
	@forge test -vv

deploy-sepolia:
	@forge script script/Crowdfunding.s.sol \
		--rpc-url $(SEPOLIA_RPC_URL) \
		--broadcast \
		--verify \
		--etherscan-api-key $(ETHERSCAN_API_KEY) \
		-vvvv
