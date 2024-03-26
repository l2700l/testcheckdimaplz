refresh:
	sudo rm -rf ./eth-net/node1/*
	sudo rm -rf ./eth-net/node2/*
	docker run --rm -v ${PWD}/eth-net:/sources ethereum/client-go:alltools-v1.11.2 geth --datadir /sources/node1 init /sources/genesis.json
	docker run --rm -v ${PWD}/eth-net:/sources ethereum/client-go:alltools-v1.11.2 geth --datadir /sources/node2 init /sources/genesis.json
	sudo cp ./eth-net/keystore/* ./eth-net/node1/keystore
	sudo cp ./eth-net/keystore/* ./eth-net/node2/keystore
	sudo chmod -R 777 ./eth-net/

amidtoken:
	make refresh
	docker run --rm -v ${PWD}/contract:/sources ethereum/solc:0.8.0 --abi --bin /sources/ProfessionalContract.sol -o /sources --overwrite 
	docker run --rm -v ${PWD}/contract:/sources ethereum/client-go:alltools-v1.11.2 abigen --abi /sources/PROFIContract.abi --bin /sources/PROFIContract.bin --pkg contract --out /sources/PROFIContract.go
	docker run --rm -v ${PWD}/contract:/sources ethereum/client-go:alltools-v1.11.2 abigen --abi /sources/NFTContract.abi --bin /sources/NFTContract.bin --pkg nft --out /sources/nft/NFTContract.go
	sudo chmod 777 contract/*
	docker-compose up -d 
stop:
	docker-compose down
	docker image rm testcheckdimaplz_api