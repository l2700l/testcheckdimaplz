// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (token/ERC1155/ERC1155.sol)

pragma solidity ^0.8.20;

// Важное по токену ERC1155:
// 1) убрали комментарии
// 2) убрали все упоминания bytes memory data
// 3) убрали кастомные revert'ы
// 4) убрали все импорты и ересь, которую превносят импорты
// 5) убрали все ивенты
// 6) изменили array.unsafeMemoryAccess(id) в списках на array[id]

// Храним структуры сверху, чтобы были доступны везде
    struct NFT {
        uint id;
        string name;
        string description;
        string image;
        mapping(address owner => uint) prices;
        uint count;
        mapping(address owner => uint) to_sales;
        uint timestamp;
        uint collection;
    }
    struct Collection {
        uint id;
        string name;
        string description;
        uint[] nftIds;
    }

// Главный контракт, в нем проводятся все расчеты между нормисами, деплоится именно он
contract PROFIContract {
    address[] public users;
    mapping(address user => uint) public balances;
    mapping(string code => address) public refCodesOwners;
    mapping(address user => bool) public useCodes;
    mapping(address owner => string) public refCodes;
    mapping(address user => uint) public discount;

    address public owner;

    // дефолт информация для ERC20
    string public name = "Professional";
    string public symbol = "PROFI";
    uint public totalSuply = 1000000;
    uint public digits = 6;

    // адрес другого контракта, нужен для того чтобы дергать его методы
    NFTContract public NFTcontract;

    constructor(address tom, address max, address jack) {
        owner = msg.sender;
        registerUser(owner, 100000);
        registerUser(tom, 200000);
        registerUser(max, 300000);
        registerUser(jack, 400000);
        NFTcontract = new NFTContract(msg.sender);
    }

    // сокральный код со времен нац чемпионата
    function getReferralCode(address addr) public pure returns (string memory) {
        bytes2 addrBytes = bytes2(bytes20(addr));
        bytes memory str = new bytes(4);
        bytes memory alph = "0123456789abcdef";
        for (uint8 i = 0; i < 2; i++)
        {
            str[i*2] = alph[uint8(addrBytes[i]) / alph.length];
            str[(i*2)+1] = alph[uint8(addrBytes[i]) % alph.length];
        }
        return string(abi.encodePacked("PROFI - ", string(str), "2024"));
    }

    function registerUser(address addr, uint balance) public {
        require(msg.sender == owner, "not owner");
        users.push(addr);
        balances[addr] = balance;
        string memory code = getReferralCode(addr);
        refCodesOwners[code] = addr;
        refCodes[addr] = code;
    }

    // юзаем рефку
    function useCode(string memory code) public {
        require(sravnit(code) != sravnit(refCodes[msg.sender]), "not use self code");
        require(useCodes[msg.sender], "already used");
        if (discount[refCodesOwners[code]] < 3) {
            discount[refCodesOwners[code]] = discount[refCodesOwners[code]] + 1;
        }
        useCodes[msg.sender] = true;
        balances[msg.sender] = balances[msg.sender] + 100;
    }

    // нужна чтобы сравнивать memory строку и storage строку
    function sravnit(string memory str) public pure returns (bytes32) {
        return keccak256(abi.encode(str));
    }

    function buyNFT(address from, uint nftId, uint amount) public {
        // такой вариант проще, потому что в структуре nft есть mapping'и
        uint cost = NFTcontract.beforeBuy(nftId, amount, from, balances[msg.sender], discount[msg.sender]);
        if (cost != 0) {
            balances[msg.sender] -= cost;
            balances[from] += cost;
            // Переводим NFT покупателю
            for (uint i = 0; i < amount; i++) {
                NFTcontract.safeTransferFrom(from, msg.sender, nftId, 1);
            }
            NFTcontract.afterBuy(nftId, amount, from);
        }
    }

    function saleNFT(uint nftId, uint price, uint count) public {
        NFTcontract.saleNFT(msg.sender, nftId, price, count);
    }

    // аукцион…
    // этот код нагенерировал чатгпт, но он не полный
    struct Auction {
        uint collectionId;
        uint startTime;
        uint endTime;
        uint startPrice;
        uint maxPrice;
        bool active;
        address highestBidder;
        uint highestBid;
    }

    // Хранение аукционов
    mapping(uint => Auction) public auctions;
    uint[] public auctionIds;

    // Функция для старта аукциона
    function startAuction(uint collectionId, uint startTime, uint endTime, uint startPrice, uint maxPrice) public {
        require(msg.sender == owner, "not owner");
        uint auctionId = auctionIds.length + 1;
        auctions[auctionId] = Auction(collectionId, startTime, endTime, startPrice, maxPrice, true, address(0), 0);
        auctionIds.push(auctionId);
    }

    // Функция для окончания аукциона
    function endAuction(uint auctionId) public {
        if(auctions[auctionId].endTime >= block.timestamp) {
            auctions[auctionId].active = false;
            // если чел бомж без денег, то аукцион закрывается без перевода коллекции
            if (balances[auctions[auctionId].highestBidder] >= auctions[auctionId].highestBid) {
                // NFTcontract.trasnferCollection(auctions[auctionId].collectionId, auctions[auctionId].highestBidder);
                balances[auctions[auctionId].highestBidder] -= auctions[auctionId].highestBid;
            }
        }
    }

    // делаем ставку
    function placeBid(uint auctionId, uint bid) public {
        require(msg.sender != owner, "owner can't place bid");
        require(auctions[auctionId].active, "auction is not active");
        if(auctions[auctionId].endTime >= block.timestamp) {
            auctions[auctionId].active = false;
            // если чел бомж без денег, то аукцион закрывается без перевода коллекции
            if (balances[auctions[auctionId].highestBidder] >= auctions[auctionId].highestBid) {
                // NFTcontract.trasnferCollection(auctions[auctionId].collectionId, auctions[auctionId].highestBidder);
                balances[auctions[auctionId].highestBidder] -= auctions[auctionId].highestBid;
            }
            revert("auction is not active");
        }
        require(auctions[auctionId].highestBidder != msg.sender, "you're highest bidder");
        require(auctions[auctionId].highestBid != bid, "your bid small then highest");
        require(balances[msg.sender] >= bid, "your bid small then highest");
        auctions[auctionId].highestBidder = msg.sender;
        auctions[auctionId].highestBid = bid;
    }
}

contract NFTContract {
    // храним данные
    mapping(uint256 id => NFT) public nft;
    mapping(uint256 id => Collection) public collection;
    mapping(uint256 id => mapping(address account => uint256)) public balances;
    uint[] public NFTs;
    uint[] public collections;

    // нужны для проверок того что дергает тот кому можно
    address public owner;
    address public PROFIcontract;

    constructor(address _owner) {
        owner = _owner;
        PROFIcontract = msg.sender;
        // минт всех нфт и коллекций
        createNFT(unicode"Герда в профиль", unicode"Скучающая хаски по имени Герда", "husky_nft1.png", 2000, 7, 0);
        createNFT(unicode"Герда на фрилансе", unicode"Герда релизнула новый проект", "husky_nft2.png", 5000, 5, 0);
        createNFT(unicode"Новогодняя Герда", unicode"Герда ждет боя курантов", "husky_nft3.png", 3500, 2, 0);
        createNFT(unicode"Герда в отпуске", unicode"Приехала отдохнуть после тяжелого проекта", "husky_nft4.png", 4000, 6, 0);
        uint catsCollection = createCollection(unicode"Космические котики", unicode"Они путешествуют по вселенной");
        createNFT(unicode"Комочек", unicode"Комочек слился с космосом", "cat_nft1.png", 0, 1, catsCollection);
        createNFT(unicode"Вкусняшка", unicode"Вкусняшка впервые пробует японскую кухню", "cat_nft2.png", 0, 1, catsCollection);
        createNFT(unicode"Пузырик", unicode"Пузырик похитил котика с Земли", "cat_nft3.png", 0, 1, catsCollection);
        uint walkerCollection = createCollection(unicode"Пешеходы", unicode"Куда они идут?");
        createNFT(unicode"Баскетболист", unicode"Он идет играть в баскетбол", "walker_nft1.png", 0, 1, walkerCollection);
        createNFT(unicode"Волшебник", unicode"Он идет колдовать", "walker_nft2.png", 0, 1, walkerCollection);
    }

    // дефолт функция из ERC1155
    function balanceOf(address account, uint256 id) public view returns (uint256) {
        return balances[id][account];
    }

    // дефолт функция из ERC1155
    function balanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    ) public view returns (uint256[] memory) {
        if (accounts.length != ids.length) {
            revert("balanceOfBatch error");
        }

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    // дефолт функция из ERC1155
    function safeTransferFrom(address from, address to, uint256 id, uint256 value) public {
        address sender = msg.sender;
        if (from != sender) {
            revert("safeTransferFrom error");
        }
        _safeTransferFrom(from, to, id, value);
    }

    // дефолт функция из ERC1155
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) public {
        address sender = msg.sender;
        if (from != sender) {
            revert("safeBatchTransferFrom error");
        }
        _safeBatchTransferFrom(from, to, ids, values);
    }

    // дефолт функция из ERC1155
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal {
        if (ids.length != values.length) {
            revert("update error");
        }

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 value = values[i];

            if (from != address(0)) {
                uint256 fromBalance = balances[id][from];
                if (fromBalance < value) {
                    revert("update balance error");
                }
                unchecked {
                // Overflow not possible: value <= fromBalance
                    balances[id][from] = fromBalance - value;
                }
            }

            if (to != address(0)) {
                balances[id][to] += value;
            }
        }
    }

    // дефолт функция из ERC1155
    function _updateWithAcceptanceCheck(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal {
        _update(from, to, ids, values);
    }

    // создание нфт и присвоение владельцу
    function createNFT(string memory name, string memory description, string memory image, uint price, uint count, uint collectionId) checkOwner public returns (uint) {
        uint id = NFTs.length+1;
        NFT storage newNft = nft[id];
        newNft.id = id;
        newNft.name = name;
        newNft.description = description;
        newNft.image = image;
        newNft.timestamp = block.timestamp;
        newNft.collection = collectionId;
        newNft.count = count;
        newNft.prices[owner] = price;
        NFTs.push(id);
        if (collectionId != 0) {
            Collection storage insertCollection = collection[collectionId];
            insertCollection.nftIds.push(id);
        }
        mint(owner, id, count);
        return id;
    }

    // создание коллекции
    function createCollection(string memory name, string memory description) checkOwner public returns (uint) {
        uint id = collections.length+1;
        uint[] memory nftIds;
        Collection storage newCollection = collection[id];
        newCollection.id = id;
        newCollection.name = name;
        newCollection.description = description;
        newCollection.nftIds = nftIds;
        collections.push(id);
        return id;
    }

    // дефолт функция из ERC1155
    function _safeTransferFrom(address from, address to, uint256 id, uint256 value) internal {
        if (to == address(0)) {
            revert("_safeTransferFrom to error");
        }
        if (from == address(0)) {
            revert("_safeTransferFrom from error");
        }
        (uint256[] memory ids, uint256[] memory values) = _asSingletonArrays(id, value);
        _updateWithAcceptanceCheck(from, to, ids, values);
    }

    // дефолт функция из ERC1155
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal {
        if (to == address(0)) {
            revert("_safeBatchTransferFrom to error");
        }
        if (from == address(0)) {
            revert("_safeBatchTransferFrom from error");
        }
        _updateWithAcceptanceCheck(from, to, ids, values);
    }

    // дефолт функция из ERC1155
    function mint(address to, uint256 id, uint256 value) checkOwner public {
        if (to == address(0)) {
            revert("mint error");
        }
        (uint256[] memory ids, uint256[] memory values) = _asSingletonArrays(id, value);
        _updateWithAcceptanceCheck(address(0), to, ids, values);
    }

    // дефолт функция из ERC1155
    function _burn(address from, uint256 id, uint256 value) internal {
        if (from == address(0)) {
            revert("burn error");
        }
        (uint256[] memory ids, uint256[] memory values) = _asSingletonArrays(id, value);
        _updateWithAcceptanceCheck(from, address(0), ids, values);
    }

    // дефолт функция из ERC1155
    function _burnBatch(address from, uint256[] memory ids, uint256[] memory values) internal {
        if (from == address(0)) {
            revert("_burnBatch error");
        }
        _updateWithAcceptanceCheck(from, address(0), ids, values);
    }

    // дефолт функция из ERC1155
    function _asSingletonArrays(
        uint256 element1,
        uint256 element2
    ) private pure returns (uint256[] memory array1, uint256[] memory array2) {
        /// @solidity memory-safe-assembly
        assembly {
        // Load the free memory pointer
            array1 := mload(0x40)
        // Set array length to 1
            mstore(array1, 1)
        // Store the single element at the next word after the length (where content starts)
            mstore(add(array1, 0x20), element1)

        // Repeat for next array locating it right after the first array
            array2 := add(array1, 0x40)
            mstore(array2, 1)
            mstore(add(array2, 0x20), element2)

        // Update the free memory pointer by pointing after the second array
            mstore(0x40, add(array2, 0x40))
        }
    }

    function beforeBuy(uint nftId, uint amount, address from, uint balance, uint discount) checkOwner public view returns(uint) {
        // Проверяем, что NFT доступен для продажи
        require(nft[nftId].collection == 0 || from != owner, "Not for simple sale");
        require(nft[nftId].to_sales[from] >= amount, "Not enough NFT available for sale");

        // Проверяем, что отправленная сумма достаточна
        require(balance >= nft[nftId].prices[from] * amount - ((nft[nftId].prices[from] * amount * discount / 100)), "Insufficient funds");
        return nft[nftId].prices[from] * amount - ((nft[nftId].prices[from] * amount * discount / 100));
    }
    function afterBuy(uint nftId, uint amount, address from) checkOwner public {
        nft[nftId].to_sales[from] -= amount;
    }

    function saleNFT(address from, uint nftId, uint price, uint count) public {
        require(nft[nftId].collection == 0 || from != owner, "Not for simple sale");
        require(balances[nftId][from] >= count, "sale count error");
        nft[nftId].prices[from] = price;
        nft[nftId].to_sales[from] = count;
    }

    function trasnferCollection(uint collectionId, address highestBidder) checkOwner public {
        Collection storage transferCollection = collection[collectionId];
        for (uint i = 0; i < transferCollection.nftIds.length; i++) {
            safeTransferFrom(owner, highestBidder, transferCollection.nftIds[i], 1);
        }
    }

    // проверка что дергает тот кому нужно
    modifier checkOwner {
        if (msg.sender != owner && msg.sender != PROFIcontract) {
            revert("not owner");
        }
        _;
    }
}