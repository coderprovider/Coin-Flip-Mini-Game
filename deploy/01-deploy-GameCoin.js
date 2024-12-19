const { developmentChains, networkConfig } = require("../helper-hardhat-config")
const { ethers, network } = require("hardhat")
const { verify } = require("../utils/verify")

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deployer } = await getNamedAccounts()
    const { deploy, log } = deployments
    const mintPriceETH = ethers.utils.parseEther("0.05")
    const mintPriceMATIC = ethers.utils.parseEther("10")
    const tokenURl = ""
    const chainId = network.config.chainId

    const blockConfirmations = developmentChains.includes(network.name) ? 1 : 6

    const mintPrice = chainId == 11155111 || chainId == 1 ? mintPriceETH : mintPriceMATIC

    args = [tokenURl, mintPrice]

    const gameCoins = await deploy("GameCoins", {
        from: deployer,
        log: true,
        args: args, //TOKENURI, MINTPRICE
        waitConfirmations: blockConfirmations,
    })

    //VERIFICATION OF CONTRACT'S ABI ON POLYSCAN
    if (
        !developmentChains.includes(network.name) &&
        process.env.POLYSCAN_API_KEY &&
        chainId == 80001
    ) {
        log("Verifying the contract on matic mumbai...")
        await verify(gameCoins.address, args)
    }

    //VERIFICATION OF CONTRACT'S ABI ON ETHERSCAN
    if (
        !developmentChains.includes(network.name) &&
        process.env.ETHERSCAN_API_KEY &&
        chainId == 11155111
    ) {
        log("Verifying the contract on sepolia network...")
        await verify(gameCoins.address, args)
    }

    //VERIFICATION OF CONTRACT'S ABI ON ETHERSCAN
    if (
        !developmentChains.includes(network.name) &&
        process.env.ETHERSCAN_API_KEY &&
        chainId == 1
    ) {
        log("Verifying the contract on ethereum mainnet...")
        await verify(gameCoins.address, args)
    }
    log("---------------------------------")
}
module.exports.tags = ["all", "gamecoins", "gamecoin", "nft", "nfts"]
