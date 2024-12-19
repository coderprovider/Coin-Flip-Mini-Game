const { ethers, network } = require("hardhat")
const fs = require("fs")

const FRONT_END_ADDRESSES_FILE =
    "../HACKATON_COINFLIP_FRONTEND/my_frontend/constants/contractAddresses.json"
const FRONT_END_ADDRESSES_FILE_GAMECOINS =
    "../HACKATON_COINFLIP_FRONTEND/my_frontend/constants/contractAddressesNFT.json"
const FRONT_END_ABI_FILE = "../HACKATON_COINFLIP_FRONTEND/my_frontend/constants/abi.json"
const FRONT_END_ABI_FILE_GAMECOINS =
    "../HACKATON_COINFLIP_FRONTEND/my_frontend/constants/abiNFT.json"

module.exports = async function () {
    if (process.env.UPDATE_FRONT_END) {
        console.log("Updating front end...")
        await updateContractAddresses()
        await updateAbi()
    }
}

//FUNCTION TO UPDATE ABI JSON FILES IN FRONTEND
async function updateAbi() {
    const coinflip = await ethers.getContract("Gameplay")
    const gamecoins = await ethers.getContract("GameCoins")
    fs.writeFileSync(FRONT_END_ABI_FILE, coinflip.interface.format(ethers.utils.FormatTypes.json))
    fs.writeFileSync(
        FRONT_END_ABI_FILE_GAMECOINS,
        gamecoins.interface.format(ethers.utils.FormatTypes.json)
    )
}

//FUNCTION TO UPDATE CONTRACT ADDRESSESS FILES IN FRONTEND
async function updateContractAddresses() {
    const coinflip = await ethers.getContract("Gameplay")
    const gamecoins = await ethers.getContract("GameCoins")
    const chainId = network.config.chainId.toString()
    const contractAddresses = JSON.parse(fs.readFileSync(FRONT_END_ADDRESSES_FILE, "utf8"))
    if (chainId in contractAddresses) {
        if (!contractAddresses[chainId].includes(coinflip.address)) {
            contractAddresses[chainId].push(coinflip.address)
        }
    } else {
        contractAddresses[chainId] = [coinflip.address]
    }
    fs.writeFileSync(FRONT_END_ADDRESSES_FILE, JSON.stringify(contractAddresses))

    const contractAddressesNFT = JSON.parse(
        fs.readFileSync(FRONT_END_ADDRESSES_FILE_GAMECOINS, "utf8")
    )
    if (chainId in contractAddressesNFT) {
        if (!contractAddressesNFT[chainId].includes(gamecoins.address)) {
            contractAddressesNFT[chainId].push(gamecoins.address)
        }
    } else {
        contractAddressesNFT[chainId] = [gamecoins.address]
    }
    fs.writeFileSync(FRONT_END_ADDRESSES_FILE_GAMECOINS, JSON.stringify(contractAddressesNFT))
}

module.exports.tags = ["all", "frontend"]
