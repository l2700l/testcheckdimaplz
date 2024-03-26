# bin/bash
geth --datadir node1 --networkid 12345 --port 30309 --http -http.port 1111 --allow-insecure-unlock --http.api admin,clique,debug,eth,miner,personal,net,txpool --syncmode full --bootnodes enode://1b6cbd0efa5ef05e2b41071431b2656d032dfdd37989d9840a91e4f95a65d3bf577137781d5b0f13706e1f107c0c2cee2e926cb719ce7bd709ddcaaad8c6e2d2@127.0.0.1:0?discport=30305
