install:
	forge install
build:
	forge build
lint:
	solhint ./contracts/**.sol
test:
	forge test -vvvv
