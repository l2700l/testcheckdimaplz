contract:
	solc --abi --bin contract/ProfessionalContract.sol -o contract --overwrite
	abigen --abi contract/PROFIContract.abi --bin contract/PROFIContract.bin --pkg contract --out contract/PROFIContract.go
	abigen --abi contract/NFTContract.abi --bin contract/NFTContract.bin --pkg nft --out contract/nft/NFTContract.go
	sudo chmod 777 contract/*

.PHONY: contract
