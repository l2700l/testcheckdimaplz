package main

import (
	"errors"
	"fmt"
	"github.com/ethereum/go-ethereum/common"
	"github.com/gin-gonic/gin"
	"io"
	"math/big"
	"net/http"
	"os"
	"professional/utils"
	"strconv"
	"time"
)

type NFTCollection struct {
	Id          *big.Int
	Name        string
	Description string
}

type NFT struct {
	Id          *big.Int
	Name        string
	Description string
	Image       string
	Count       *big.Int
	Timestamp   *big.Int
	Collection  *big.Int
}

func RedToError(ctx *gin.Context, err error) {
	ctx.Redirect(http.StatusMisdirectedRequest, "/error?message="+err.Error())
}

func RedToMain(ctx *gin.Context, addr string) {
	ctx.Redirect(http.StatusMovedPermanently, "/main?addr="+addr)
}

func main() {
	fmt.Printf("syka")
	time.Sleep(time.Second)
	utils.Init()
	c := gin.Default()

	c.LoadHTMLGlob("templates/*")

	c.Static("/js", "./node_modules/ethers/dist")
	c.Static("/nfts", "./nfts")

	c.GET("/", func(context *gin.Context) {
		context.HTML(http.StatusOK, "prelogin.html", gin.H{})
	})

	c.GET("/login", func(context *gin.Context) {
		context.HTML(http.StatusOK, "login.html", gin.H{})
	})
	c.POST("/login", func(context *gin.Context) {
		addr := common.HexToAddress(context.Request.FormValue("login"))
		password := context.Request.FormValue("password")
		acc := utils.ImportAccount(addr)
		if acc == nil {
			RedToError(context, errors.New("account not found"))
			return
		}
		err := utils.Keystore.Unlock(*acc, password)
		if err != nil {
			RedToError(context, err)
			return
		}
		RedToMain(context, addr.String())
	})
	c.GET("/error", func(context *gin.Context) {
		message := context.Query("message")
		context.HTML(http.StatusOK, "error.html", gin.H{"message": message})
	})
	c.GET("/main", func(context *gin.Context) {
		addr := common.HexToAddress(context.Request.FormValue("addr"))
		refCode, _ := utils.Contract.RefCodes(utils.DefaultCallOpts(), addr)
		discount, _ := utils.Contract.Discount(utils.DefaultCallOpts(), addr)
		template := "main.html"
		collections := GetAllNftCollections()

		if addr == utils.Owner {
			template = "owner.html"
		}

		context.HTML(http.StatusOK, template, gin.H{
			"addr":        addr,
			"refCode":     refCode,
			"discount":    discount,
			"collections": collections,
		})
	})
	c.POST("/ref-code", func(context *gin.Context) {
		addr := context.Query("addr")
		code := context.Request.FormValue("code")
		_, err := utils.Contract.UseCode(utils.DefaultTransactOpts(), code)
		if err != nil {
			RedToError(context, err)
			return
		}
		RedToMain(context, addr)
	})
	c.GET("/nft", func(context *gin.Context) {
		addr := context.Query("addr")
		collectionId, _ := strconv.ParseInt(context.Query("collectionId"), 0, 64)
		nfts := GetAllNft(big.NewInt(collectionId))
		fmt.Printf("%v", nfts)
		context.HTML(http.StatusOK, "nft.html", gin.H{
			"collectionId": collectionId,
			"addr":         addr,
			"nfts":         nfts,
		})
	})
	c.POST("/nft", func(context *gin.Context) {
		addr := context.Query("addr")
		name := context.Request.FormValue("name")
		desc := context.Request.FormValue("desc")
		price, _ := strconv.ParseInt(context.Request.FormValue("price"), 0, 64)
		count, _ := strconv.ParseInt(context.Request.FormValue("count"), 0, 64)
		collectionId, _ := strconv.ParseInt(context.Query("collectionId"), 0, 64)

		file, handler, _ := context.Request.FormFile("image")
		defer file.Close()
		filePatch := "/resources/" + handler.Filename
		dst, _ := os.Create(filePatch)
		defer dst.Close()
		io.Copy(dst, file)

		_, err := utils.NFTContract.CreateNFT(utils.DefaultTransactOpts(), name, desc, filePatch,
			big.NewInt(price), big.NewInt(count), big.NewInt(collectionId))

		if err != nil {
			RedToError(context, err)
			return
		}

		RedToMain(context, addr)
	})

	c.Run("0.0.0.0:1212")
}

func GetAllNftCollections() []NFTCollection {
	var index int64 = 0
	collections := make([]NFTCollection, 0)
	for {
		col, err := GetNftCollectionById(index)
		if err != nil {
			break
		}
		collections = append(collections, col)
		index++
	}
	return collections
}

func GetNftCollectionById(uid int64) (NFTCollection, error) {
	id, err := utils.NFTContract.Collections(utils.DefaultCallOpts(), big.NewInt(uid))
	if err != nil {
		return NFTCollection{}, err
	}
	return utils.NFTContract.Collection(utils.DefaultCallOpts(), id)
}

func GetAllNft(collectionId *big.Int) []NFT {
	var index int64 = 0
	nfts := make([]NFT, 0)
	for {
		nft, err := GetNFTById(index)
		if err != nil {
			break
		}
		index++
		if nft.Collection.Int64() != collectionId.Int64() {
			continue
		}
		nfts = append(nfts, nft)
	}
	return nfts
}

func GetNFTById(id int64) (NFT, error) {
	nId, err := utils.NFTContract.NFTs(utils.DefaultCallOpts(), big.NewInt(id))
	if err != nil {
		return NFT{}, err
	}
	return utils.NFTContract.Nft(utils.DefaultCallOpts(), nId)
}
