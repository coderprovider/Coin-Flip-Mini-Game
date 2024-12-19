// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/ConfirmedOwner.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./GameCoin.sol";

// ADD IN INDEXED AT CREATE AND JOIN GAME AT ACCOUNT, CREATE CRETORSYMBOL IN MAPPING AND EVENT

/**@title A Coin Flip mini game
 * @author Jaka Potokar
 * @notice This contract make a coin flip mini game platform
 * @dev This implements the Chainlink VRF Version 2
 * MY NOTICE: CORRECT THE TRANSFER FUNCTION BECAUSE IT CAN GET HACKED, BECAUSE CALLER DOESN'T NEED TO BE REQUIRED
 */
contract Gameplay is VRFConsumerBaseV2, ConfirmedOwner {
    //ERRORS
    error CoinFlip_notEnoughFunds();
    error CoinFlip_incorrectAddress();
    error CoinFlip_betAmountTooLow();
    error CoinFlip_noGameFoundWithThisAmount();
    error CoinFlip_notAnNftOwner();

    //EVENTS
    event gameCreated(
        uint256 indexed _gameId,
        address indexed _challenger,
        uint256 _amount,
        Symbol _creatorSymbol
    );
    event gameStarted(
        uint256 indexed _gameId,
        address indexed _challenger,
        address indexed _joiner,
        uint256 _amount,
        Symbol _creatorSymbol
    );
    event gameFinished(
        uint256 indexed _gameId,
        address indexed _winner,
        address indexed _loser,
        uint256 _amount
    );
    event amountTransfered(address indexed _sender, address indexed _receiver, uint256 _amount);
    event RequestedWinner(uint256 indexed requestId);
    event coinFlipResult(uint256 indexed _gameId, Symbol _winningSymbol);

    //VRF COORDINATOR VARIABLES
    uint64 private immutable s_subscriptionId;
    VRFCoordinatorV2Interface COORDINATOR;
    bytes32 private immutable s_keyHash;
    uint32 private immutable s_callbackGasLimit;
    uint16 private immutable requestConfirmations = 3;
    uint32 private immutable numWords = 7;
    GameCoins public gamecoins;

    //CONSTRUCTOR
    //vrfCoordinator address for mumbai 0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed
    //vrfCoordinator address for Matic mainnet 0xAE975071Be8F8eE67addBC1A82488F1C24858067
    constructor(
        address vrfCoordinatorAddress,
        uint256 _gameFee,
        uint64 subsriptionId,
        bytes32 keyHash,
        uint32 callbackGasLimit,
        address _gamecoins
    ) VRFConsumerBaseV2(vrfCoordinatorAddress) ConfirmedOwner(msg.sender) {
        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinatorAddress);
        gameOwner = msg.sender;
        gameFee = _gameFee;
        s_subscriptionId = subsriptionId;
        s_keyHash = keyHash;
        s_callbackGasLimit = callbackGasLimit;
        gamecoins = GameCoins(_gamecoins);
    }

    //CHECKS IF THE ADDRESS OWNS THE NFT
    modifier nftOwner() {
        if (gamecoins.balanceOf(msg.sender) == 0) {
            revert CoinFlip_notAnNftOwner();
        }
        _;
    }

    //COIN FLIP VARIABLES
    //ENUM HEADS/TAILS, CHANCE OF WIN, GAMEID(updates after every game)
    enum Symbol {
        Heads,
        Tails
    }
    uint256 public probability = 50;
    uint256 public immutable gameFee;
    uint256 public gameId;
    address private immutable gameOwner;
    uint256 public minBet = 100000000000000000; // MIN BET 0.1 MATIC/ETHER

    //GAMES STRUCTS, TO GET THE DATA FROM EACH GAME
    struct availableGame {
        uint256 _gameId;
        address _challenger;
        uint256 _amount;
        Symbol _symbol; // THE CREATOR GETS TO CHOOSE HIS/HERS SYMBOL HEADS/TAILS
    }

    struct gameInProgress {
        uint256 _gameId;
        address _challenger;
        address _joiner;
        uint256 _amount;
        Symbol _symbol; // CREATOR CHOOSING OF THE SYMBOL
    }

    struct finishedGame {
        uint256 _gameId;
        address _winner;
        address _loser;
        uint256 _amount;
    }

    //GAME ARRAYS TO STORE GAMES
    availableGame[] public availableGames;
    gameInProgress[] public gamesInProgress;
    finishedGame[] public finishedGames;

    //BALANCE OF USER
    mapping(address => uint256) public balance;

    //TRANSFER FUNCTIONALITY
    function _transfer(address _sender, address _receiver, uint256 _amount) internal {
        balance[_sender] -= _amount;
        balance[_receiver] += _amount;
    }

    //DEPOSIT FUNCTION
    function deposit() public payable {
        balance[msg.sender] += msg.value;
    }

    //WITHDRAW FUNCTION
    function withdraw(uint256 _amount) public payable {
        if (balance[msg.sender] < _amount) {
            revert CoinFlip_notEnoughFunds();
        }
        balance[msg.sender] -= _amount;
        //WITHDRAW CALL
        (bool callSuccess, ) = payable(msg.sender).call{value: _amount}("");
        require(callSuccess, "Call failed");
    }

    //FUNCTION TO START THE GAME
    function startGame(uint256 _amount, Symbol _symbol) public nftOwner {
        if (_amount < minBet) {
            revert CoinFlip_betAmountTooLow();
        }
        if (balance[msg.sender] < _amount) {
            revert CoinFlip_notEnoughFunds();
        }
        _transfer(msg.sender, gameOwner, _amount);
        availableGames.push(availableGame(gameId, msg.sender, _amount, _symbol));
        emit gameCreated(gameId, msg.sender, _amount, _symbol);
        gameId++;
    }

    //FUNCTION TO LET OWNER CANCEL THE MATCH IF NOBODY ENTERS, THE MONEY IS RETURNED IN FULL
    function cancelGame(uint256 _gameId) public nftOwner {
        //FINDING THE GAME WITH THE SAME ID IN AN ARRAY
        for (uint256 i = 0; i < availableGames.length; i++) {
            if (availableGames[i]._gameId == _gameId) {
                if (availableGames[i]._challenger != msg.sender) {
                    revert CoinFlip_incorrectAddress();
                }
                uint256 transferAmount = availableGames[i]._amount;
                _transfer(gameOwner, msg.sender, transferAmount);

                //POP OUT THE CANCELED GAME
                availableGames[i] = availableGames[availableGames.length - 1];
                availableGames.pop();
                break;
            }
        }
    }

    //FUNCTION TO JOIN A GAME
    function joinGame(uint256 _amount) public nftOwner {
        if (_amount < minBet) {
            revert CoinFlip_betAmountTooLow();
        }
        if (balance[msg.sender] < _amount) {
            revert CoinFlip_notEnoughFunds();
        }
        uint256 gamejoined;
        //FINDING THE GAME THAT HAS THE SAME AMOUNT THAT THE USER WANTS TO PLAY WITH
        for (uint256 i = 0; i < availableGames.length; i++) {
            if (availableGames[i]._amount == _amount) {
                gamesInProgress.push(
                    gameInProgress(
                        availableGames[i]._gameId,
                        availableGames[i]._challenger,
                        msg.sender,
                        availableGames[i]._amount,
                        availableGames[i]._symbol
                    )
                );
                gamejoined = availableGames[i]._gameId;
                _transfer(msg.sender, gameOwner, _amount);
                emit gameStarted(
                    availableGames[i]._gameId,
                    availableGames[i]._challenger,
                    msg.sender,
                    availableGames[i]._amount,
                    availableGames[i]._symbol
                );
                //POPS OUT GAME OUT OF AVAILABLE GAMES
                availableGames[i] = availableGames[availableGames.length - 1];
                availableGames.pop();
                break;
            } else {
                if (
                    availableGames[i]._gameId == availableGames[availableGames.length - 1]._gameId
                ) {
                    revert CoinFlip_noGameFoundWithThisAmount();
                }
            }
        }
        //HERE WE START THE GAME LOGIC WITH VRF GAMELOGIC AND ENDGAME
        requestRandomWords(gamejoined);
    }

    //FUNCTION WHICH IS CALLED AT THE END OF THE GAME TO TRANSFER TOKENS, STORE FINISHEDGAMES AND DISCARDING THE GAMES OUT OF GAMES IN PROGRESS
    function endGame(uint256 _gameId, address _winner, address _loser, uint256 _winnings) internal {
        finishedGames.push(finishedGame(_gameId, _winner, _loser, _winnings));
        uint256 playerWinnings = _winnings - gameFee;
        _transfer(gameOwner, _winner, playerWinnings);
        for (uint256 i = 0; i < gamesInProgress.length; i++) {
            if (gamesInProgress[i]._gameId == _gameId) {
                // delete gamesInProgress[i];
                gamesInProgress[i] = gamesInProgress[gamesInProgress.length - 1];
                gamesInProgress.pop();
                break;
            }
        }
        emit gameFinished(_gameId, _winner, _loser, _winnings);

        //TO CHANGE NFT STATS
        uint256 winnersNFT = gamecoins.getOwnersToken(_winner);
        uint256 losersNFT = gamecoins.getOwnersToken(_loser);
        gamecoins.addWin(winnersNFT);
        gamecoins.addLoss(losersNFT);
        gamecoins.changeAmountWon(winnersNFT, int256(_winnings / 2));
        gamecoins.changeAmountWon(losersNFT, -int256(_winnings / 2));
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////
    //VRF RANDOMNUMBER CHAINLINK IMPLEMENTATION PART
    //VRF FUNCTIONS AND LOGIC

    struct subscriptionRequest {
        uint256 _gameId;
        bool _fulfilled;
        uint256[] randomValues;
    }

    //MAPPING TO MATCH SUBSCRIPTIONID TO THE GAME, BOOL OF FULLFILMENT, AND RANDOMVALUE
    mapping(uint256 => subscriptionRequest) public wordRequests;

    //START THE VRF RANDOM WORD GENERATOR
    function requestRandomWords(uint256 _gameId) internal returns (uint256 requestId) {
        requestId = COORDINATOR.requestRandomWords(
            s_keyHash,
            s_subscriptionId,
            requestConfirmations,
            s_callbackGasLimit,
            numWords
        );
        wordRequests[requestId] = subscriptionRequest(_gameId, false, new uint256[](0));
        emit RequestedWinner(requestId);
        lastRequestId = requestId;
        return requestId;
    }

    //GET THE WINNER BACK AND END GAME
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        wordRequests[requestId]._fulfilled = true;
        wordRequests[requestId].randomValues = randomWords;
        Symbol creatorSymbol;
        address creator;
        address joiner;
        uint256 winnings;
        for (uint256 i; i < gamesInProgress.length; i++) {
            if (gamesInProgress[i]._gameId == wordRequests[requestId]._gameId) {
                creatorSymbol = gamesInProgress[i]._symbol;
                creator = gamesInProgress[i]._challenger;
                joiner = gamesInProgress[i]._joiner;
                winnings = gamesInProgress[i]._amount * 2;
                break;
            }
        }
        uint256 headWins;
        uint256 tailsWins;
        for (uint256 i = 0; i < numWords; i++) {
            Symbol winningSymbol = gameLogic(randomWords[i]); // CHANGE GAME LOGIC TO ONLY RECEIVE A UINT256
            if (winningSymbol == Symbol.Heads) {
                headWins++;
                emit coinFlipResult(wordRequests[requestId]._gameId, Symbol.Heads);
            } else {
                tailsWins++;
                emit coinFlipResult(wordRequests[requestId]._gameId, Symbol.Tails);
            }
            if (headWins > 3) {
                winningSymbol = Symbol.Heads;
                if (winningSymbol == creatorSymbol) {
                    endGame(wordRequests[requestId]._gameId, creator, joiner, winnings);
                } else {
                    endGame(wordRequests[requestId]._gameId, joiner, creator, winnings);
                }
                break;
            }
            if (tailsWins > 3) {
                winningSymbol = Symbol.Tails;
                if (winningSymbol == creatorSymbol) {
                    endGame(wordRequests[requestId]._gameId, creator, joiner, winnings);
                } else {
                    endGame(wordRequests[requestId]._gameId, joiner, creator, winnings);
                }
                break;
            }
        }
    }

    //LOGIC COIN FLIP
    // if a randomnumber % 100 is more than 50 it is heads, if less then it is tails
    function gameLogic(uint256 randValue) public view returns (Symbol) {
        uint256 calc = randValue % 100;
        Symbol _symbol;
        if (calc > probability) {
            _symbol = Symbol.Heads;
        } else {
            _symbol = Symbol.Tails;
        }
        return _symbol;
    }

    /////////////////////////////////////////////////////////////////////////////////////////////////

    //VIEW FUNCTIONS

    //TO GET THE BALANCE OF A PERSON
    function balanceOf(address _address) public view returns (uint256) {
        return balance[_address];
    }

    //GET THE NUMBER OF GAMES OPEN BASED ON SPECIFIC AMOUNT A USER WANT TO PLAY WITH
    function allGamesBasedOnAmount(uint256 _amount) public view returns (uint256) {
        uint256 numberOfGames = 0;
        for (uint256 i; i < availableGames.length; i++) {
            if (availableGames[i]._amount == _amount) {
                numberOfGames++;
            }
        }
        return numberOfGames;
    }

    //GET THE NUMBER OF AVAILABLE GAMES
    function allAvailableGames() public view returns (uint256) {
        return availableGames.length;
    }

    //GET THE NUMBER OF GAMES IN PROGRESS
    function allGamesInProgress() public view returns (uint256) {
        return gamesInProgress.length;
    }

    //GET THE NUMBER OF FINISHED GAMES
    function allFinishedGames() public view returns (uint256) {
        return finishedGames.length;
    }

    //CHECK WINNER OF THE GAME
    function viewWinner(uint256 _gameId) public view returns (address) {
        address viewWinnerAddress;
        for (uint256 i; i < finishedGames.length; i++) {
            if (finishedGames[i]._gameId == _gameId) {
                viewWinnerAddress = finishedGames[i]._winner;
            }
        }
        return viewWinnerAddress;
    }

    //GET GAME NUMBER
    function viewGameNumber() public view returns (uint256) {
        return gameId;
    }

    //GET GAME FEE
    function getGameFee() public view returns (uint256) {
        return gameFee;
    }

    //TO GET THE RANDOM VALUES - TO TEST THE RANDOMNESS AND GAMELOGIC
    uint256 lastRequestId;

    function getGameIdRandomValues() public view returns (uint256[] memory) {
        return wordRequests[lastRequestId].randomValues;
    }
}
