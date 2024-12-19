const { deployments, ethers, network, getNamedAccounts } = require("hardhat")
const { developmentChains, networkConfig } = require("../helper-hardhat-config")
const { config } = require("dotenv")

//SCRIPT TO APPROVE CONTRACT FOR OUR GAMECOIN IMPLEMENTATION
async function addSmartContract() {
    console.log("Connecting to contracts...")
    const { deployer } = await getNamedAccounts()
    const gamecoins = await ethers.getContract("GameCoins", deployer)
    const gameplay = await ethers.getContract("Gameplay")
    console.log("Adding the Contract...")
    const addContract = await gamecoins.addContract(gameplay.address)
    if (!developmentChains.includes(network.name)) {
        await addContract.wait(1)
    }
    console.log("The Contract has been successfuly added!")
}

addSmartContract()
    .then(() => process.exit(0))
    .catch((e) => {
        console.error(e)
        process.exit(1)
    })
