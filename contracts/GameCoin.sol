// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract GameCoins is ERC721, Ownable {
    //ERRORS
    error GameCoins_AlreadyOwnsACoin();
    error GameCoins_AddressNotAllowedThisFunction();
    error GameCoins_NotEnoughValueSent();
    error GameCoins_ContractAlreadyConnected();
    error GameCoins_TokenIdDoesntExist();
    error GameCoins_AddressIsNotAnOwner();

    //COIN COUNTER
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    string private TOKENURI;
    uint256 public mintPrice;
    struct coinAttributes {
        uint256 _wins;
        uint256 _losses;
        int256 _amountWon;
    }
    address private contractOwner;

    //MODIFIER FOR CONTRACT OWNERSHIP
    modifier isContractOwner() {
        if (msg.sender != contractOwner) {
            revert GameCoins_AddressNotAllowedThisFunction();
        }
        _;
    }

    //MODIFIER FOR APPROVED CONTRACTS
    modifier connectedContract() {
        bool contractIsConnected = false;
        for (uint256 i; i < connectedContracts.length; i++) {
            if (connectedContracts[i] == msg.sender) {
                contractIsConnected = true;
                break;
            }
        }
        if (!contractIsConnected) {
            revert GameCoins_AddressNotAllowedThisFunction();
        }
        _;
    }

    //MAPPING TO STORE TOKENATTRIBUTES
    mapping(uint256 => coinAttributes) public addressAttributes;

    constructor(string memory _tokenURI, uint256 _mintPrice) ERC721("GAMECOINS", "GMC") {
        TOKENURI = _tokenURI;
        contractOwner = msg.sender;
        mintPrice = _mintPrice;
    }

    //PERMISSION TO ADD AND WINS, LOSSES, AMOUNT WON
    //In case there will be more games that will use these nfts
    address[] public connectedContracts;

    function addContract(address _contract) public isContractOwner {
        for (uint256 i; i < connectedContracts.length; i++) {
            if (connectedContracts[i] == _contract) {
                revert GameCoins_ContractAlreadyConnected();
            }
        }
        connectedContracts.push(_contract);
    }

    //MINTING THE NFT, NO WHITELIST REQUIRED, ONLY ONE PER PERSON
    function nftMint() public payable {
        if (balanceOf(msg.sender) > 0) {
            revert GameCoins_AlreadyOwnsACoin();
            //Only one coin per person
        }
        if (msg.sender != tx.origin) {
            revert GameCoins_AddressNotAllowedThisFunction();
            //Only wallets allowed, no smart contracts
        }
        if (msg.value < mintPrice) {
            revert GameCoins_NotEnoughValueSent();
        }
        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(msg.sender, tokenId);
        addressAttributes[tokenId] = coinAttributes(0, 0, 0);
        _tokenIdCounter.increment();
    }

    //ADS THE TOKEN URI
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        // require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return TOKENURI;
    }

    //VIEWING ATTRIBUTES BASED ON TOKEN ID
    function seeAttributes(uint256 _tokenId) public view returns (coinAttributes memory) {
        if (_tokenId > _tokenIdCounter.current()) {
            revert GameCoins_TokenIdDoesntExist();
        }
        return addressAttributes[_tokenId];
    }

    function getWins(uint256 _tokenId) public view returns (uint256) {
        if (_tokenId > _tokenIdCounter.current()) {
            revert GameCoins_TokenIdDoesntExist();
        }
        return addressAttributes[_tokenId]._wins;
    }

    function getLosses(uint256 _tokenId) public view returns (uint256) {
        if (_tokenId > _tokenIdCounter.current()) {
            revert GameCoins_TokenIdDoesntExist();
        }
        return addressAttributes[_tokenId]._losses;
    }

    function getAmountWon(uint256 _tokenId) public view returns (int256) {
        if (_tokenId > _tokenIdCounter.current()) {
            revert GameCoins_TokenIdDoesntExist();
        }
        return addressAttributes[_tokenId]._amountWon;
    }

    function getTokenCounter() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    //TO FIND THE TOKENID OF THE OWNER
    function getOwnersToken(address _ownerAddress) public view returns (uint256) {
        if (balanceOf(_ownerAddress) == 0) {
            revert GameCoins_AddressIsNotAnOwner();
        }
        uint256 ownerTokenId;
        for (uint256 i; i < _tokenIdCounter.current(); i++) {
            if (ownerOf(i) == _ownerAddress) {
                ownerTokenId = i;
            }
        }
        return ownerTokenId;
    }

    //RETURNS IF THE CONTRACT IS APPROVED BY THIS CONTRACT
    function isContractConnected(address _address) public view returns (bool) {
        bool isConnected = false;
        for (uint256 i; i < connectedContracts.length; i++) {
            if (_address == connectedContracts[i]) {
                isConnected = true;
                break;
            }
        }
        return isConnected;
    }

    //ADDING ATTRIBUTES, ONLY IF A CONTRACT IS APPROVED
    function addWin(uint256 _tokenId) external connectedContract {
        addressAttributes[_tokenId]._wins += 1;
    }

    function addLoss(uint256 _tokenId) external connectedContract {
        addressAttributes[_tokenId]._losses += 1;
    }

    function changeAmountWon(uint256 _tokenId, int256 _amount) external connectedContract {
        addressAttributes[_tokenId]._amountWon += _amount;
    }
}
