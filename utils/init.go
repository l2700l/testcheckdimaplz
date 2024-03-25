package utils

import (
	"context"
	"github.com/ethereum/go-ethereum/accounts"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/accounts/keystore"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/ethclient"
	"log"
	"math/big"
	"professional/contract"
	"professional/contract/nft"
	"time"
)

const (
	Node2         = "http://0.0.0.0:2223"
	Node2Keystore = "./network/keystore"
)

var (
	Owner    = common.HexToAddress("0x09cb8451F147395300ccF38FC1372662f3ab9BeA")
	OwnerPWD = "owner"
	Tom      = common.HexToAddress("0xd719CB5E381Be60E1A936CcE9fbAc5Ebc3c49DbF")
	TomPWD   = "tom"
	Max      = common.HexToAddress("0x4718D993089E0E502f82746482C59bbcB5C1D977")
	MaxPWD   = "max"
	Jack     = common.HexToAddress("0x7c9294cBDbE0c0D49e1F65126548bA430BDef080")
	JackPWD  = "jack"
)

var (
	Client      *ethclient.Client
	Keystore    *keystore.KeyStore
	Contract    *contract.Contract
	NFTContract *nft.Nft
)

func Init() {
	c, err := ethclient.Dial(Node2)
	if err != nil {
		log.Fatal(err.Error())
	}
	Client = c
	k := keystore.NewKeyStore(Node2Keystore, keystore.StandardScryptN, keystore.StandardScryptP)
	Keystore = k
	Keystore.Unlock(*ImportAccount(Owner), OwnerPWD)
	_, _, con, err := contract.DeployContract(DefaultTransactOpts(), Client, Tom, Max, Jack)
	time.Sleep(time.Second * 10)
	if err != nil {
		log.Fatal(err)
	}
	Contract = con
	nftAddr, err := Contract.NFTcontract(DefaultCallOpts())
	if err != nil {
		log.Fatal(err.Error())
	}
	n, _ := nft.NewNft(nftAddr, Client)
	NFTContract = n
	Keystore.Unlock(*ImportAccount(Tom), TomPWD)
	Keystore.Unlock(*ImportAccount(Max), MaxPWD)
	Keystore.Unlock(*ImportAccount(Jack), JackPWD)
}

func ImportAccount(addr common.Address) *accounts.Account {
	for _, a := range Keystore.Accounts() {
		if a.Address == addr {
			return &a
		}
	}
	return nil
}

func TransactOpts(from common.Address, value *big.Int) *bind.TransactOpts {
	acc := ImportAccount(from)
	chainId, _ := Client.ChainID(context.Background())
	auth, _ := bind.NewKeyStoreTransactorWithChainID(Keystore, *acc, chainId)
	auth.From = from
	auth.Value = value
	gasPrice, _ := Client.SuggestGasPrice(context.Background())
	auth.GasPrice = gasPrice
	return auth
}

func DefaultTransactOpts() *bind.TransactOpts {
	return TransactOpts(Owner, big.NewInt(0))
}

func NewCallOpts(from common.Address) *bind.CallOpts {
	blockNumber, _ := Client.BlockNumber(context.Background())
	return &bind.CallOpts{
		Pending: true, From: from,
		BlockNumber: big.NewInt(int64(blockNumber)),
		Context:     context.Background(),
	}
}

func DefaultCallOpts() *bind.CallOpts {
	return NewCallOpts(Owner)
}
