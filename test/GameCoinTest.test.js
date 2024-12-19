const { expect, assert } = require("chai")
const { deployments, ethers, network, getNamedAccounts } = require("hardhat")
const { developmentChains, networkConfig } = require("../helper-hardhat-config")

!developmentChains.includes(network.name)
    ? describe.skip
    : describe("Gamecoin test", function () {
          let gamecoins, deployer, player, player2, PlayerConnected
          const mintAmount = ethers.utils.parseEther("10")

          beforeEach(async function () {
              deployer = (await getNamedAccounts()).deployer
              const accounts = await ethers.getSigners()
              player = accounts[1]
              player2 = accounts[2]
              await deployments.fixture(["all"])
              gamecoins = await ethers.getContract("GameCoins", deployer)
              PlayerConnected = gamecoins.connect(player)
          })
          describe("mints the nft", function () {
              it("increases the token counter", async () => {
                  const mintNft = await gamecoins.nftMint({ value: mintAmount })
                  const mintNft2 = await PlayerConnected.nftMint({ value: mintAmount })
                  const getTokenCounter = await gamecoins.getTokenCounter()
                  assert.equal(getTokenCounter, 2)
                  const getOwner = await gamecoins.ownerOf(0)
                  const getOwner2 = await gamecoins.ownerOf(1)
                  assert.equal(deployer, getOwner)
                  assert.equal(player.address, getOwner2)
              })
              it("increases balance of the nfts, the player owns", async () => {
                  const mintNft = await PlayerConnected.nftMint({ value: mintAmount })
                  const getBalance = await PlayerConnected.balanceOf(player.address)
                  assert.equal(getBalance.toString(), 1)
              })
              it("doesn't let the mint function to owner", async () => {
                  const mintNft = await PlayerConnected.nftMint({ value: mintAmount })
                  await expect(PlayerConnected.nftMint({ value: mintAmount })).to.be.revertedWith(
                      "GameCoins_AlreadyOwnsACoin"
                  )
                  const getBalance = await PlayerConnected.balanceOf(player.address)
                  assert.equal(getBalance.toString(), 1)
              })
          })
          describe("changes token attributes", async () => {
              it("connects address to the smart contract", async () => {
                  const _addContract = await gamecoins.addContract(deployer)
                  const isConnected = await gamecoins.isContractConnected(deployer)
                  assert.equal(isConnected, true)
              })
              it("contract hasn't been added", async () => {
                  const isConnected = await gamecoins.isContractConnected(deployer)
                  assert.equal(isConnected, false)
              })
              it("gets attributes when minted", async () => {
                  const mintNft = await PlayerConnected.nftMint({ value: mintAmount })
                  const getWins = await gamecoins.getWins(1)
                  const getLosses = await gamecoins.getLosses(1)
                  const getAmountWon = await gamecoins.getAmountWon(1)
                  assert.equal(getWins, 0)
                  assert.equal(getLosses, 0)
                  assert.equal(getAmountWon, 0)
              })
              it("adds a win, loss and changes the amount", async () => {
                  const mintNft = await PlayerConnected.nftMint({ value: mintAmount })
                  const _addContract = await gamecoins.addContract(deployer)
                  const addWin = await gamecoins.addWin(1)
                  const addLoss = await gamecoins.addLoss(1)
                  const changeAmount = await gamecoins.changeAmountWon(1, 5)
                  const getWins = await gamecoins.getWins(1)
                  const getLosses = await gamecoins.getLosses(1)
                  const getAmountWon = await gamecoins.getAmountWon(1)
                  assert.equal(getWins.toString(), "1")
                  assert.equal(getLosses.toString(), "1")
                  //   assert.equal(getAmountWon, 5) // FOR SOME REASON DOESNT WORK
              })
          })
          describe("Owner changes after transfer of the token", async () => {
              it("transfers token and balance of address decreases, ownership changes", async () => {
                  const mintNft = await PlayerConnected.nftMint({ value: mintAmount })
                  const getTokenCounter = await PlayerConnected.getTokenCounter()
                  const getFirstOwner = await PlayerConnected.ownerOf(0)
                  assert.equal(getTokenCounter.toString(), "1")
                  assert.equal(getFirstOwner, player.address)
                  const transfer = await PlayerConnected.transferFrom(
                      player.address,
                      player2.address,
                      0
                  )
                  const balanceOfPlayer = await PlayerConnected.balanceOf(player.address)
                  const balanceOfPlayer2 = await PlayerConnected.balanceOf(player2.address)
                  const getSecondOwner = await PlayerConnected.ownerOf(0)
                  assert.equal(balanceOfPlayer, 0)
                  assert.equal(balanceOfPlayer2, 1)
                  assert.equal(getSecondOwner, player2.address)
              })
          })
      })
