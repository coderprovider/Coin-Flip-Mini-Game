const { getNamedAccounts, ethers } = require("hardhat")

async function JoinGame() {
    console.log("Connecting to the contracts...")
    const { deployer } = await getNamedAccounts()
    const amount = ethers.utils.parseEther("0.1")
    const contract = await ethers.getContract("Gameplay")
    console.log("Connected!")
    // console.log("Creating a game...")
    // const startGame = await contract.startGame(amount, 1)
    // await startGame.wait(1)
    // console.log("The game has been created!")
    console.log("Getting available games...")
    const availableGames = await contract.allGamesBasedOnAmount(amount)
    if (availableGames.toString() === "0") {
        console.log("No games available")
        return
    }
    console.log(`There are ${availableGames.toString()} currently available based on the amount!`)
    console.log("Joining the game...")
    const joinGame = await contract.joinGame(amount)
    await joinGame.wait(1)
    console.log("Joined a game!")
}

JoinGame()
    .then(() => process.exit(0))
    .catch((e) => {
        console.error(e)
        process.exit(1)
    })
