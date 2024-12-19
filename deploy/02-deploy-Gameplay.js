const { developmentChains, networkConfig } = require("../helper-hardhat-config")
const { ethers, network } = require("hardhat")
const { verify } = require("../utils/verify")

module.exports = async function ({ getNamedAccounts, deployments }) {
    //VARIABLES WHICH CHANGE DEPENDING ON DEPLOYMENT NETWORK
    let vrfCoordinatorV2Address, subscriptionId, vrfCoordinatorV2Mock
    const waitBlockConfirmations = developmentChains.includes(network.name) ? 1 : 6

    //AMOUNT OF LINK WE NEED TO SUCCESFULLY FUND THE MOCK SUBSCRIPTION
    const MOCK_VRF_FUND = ethers.utils.parseEther("30")

    //CONSTRUCTOR PARAMETERS
    const { deployer } = await getNamedAccounts()
    const { deploy, log } = deployments
    const chainId = network.config.chainId
    const gameFee = networkConfig[chainId]["gameFee"]
    const callBackGasLimit = networkConfig[chainId]["callbackGasLimit"]
    const gasLane = networkConfig[chainId]["gasLane"]
    const nftAddress = await ethers.getContract("GameCoins") //FIRST DEPLOY GAMECOINS TO GET THIS ADDRESS

    //MOCK VARIABLE
    if (!developmentChains.includes(network.name)) {
        vrfCoordinatorV2Address = networkConfig[chainId]["vrfCoordinatorV2"]
        subscriptionId = networkConfig[chainId]["subscriptionId"]
    } else {
        vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock", deployer)
        vrfCoordinatorV2Address = vrfCoordinatorV2Mock.address
        const txresponse = await vrfCoordinatorV2Mock.createSubscription()
        const txreceipt = await txresponse.wait(1)
        subscriptionId = txreceipt.events[0].args.subId
        await vrfCoordinatorV2Mock.fundSubscription(subscriptionId, MOCK_VRF_FUND)
    }

    //DEPLOYMENT OF THE CONTRACT
    const args = [
        vrfCoordinatorV2Address,
        gameFee,
        subscriptionId,
        gasLane,
        callBackGasLimit,
        nftAddress.address,
    ]
    const CoinFlip = await deploy("Gameplay", {
        from: deployer,
        log: true,
        args: args,
        waitConfirmations: waitBlockConfirmations,
    })

    //ADDING CONSUMER IN CASE OF DEPLOYING TO MUMBAI TESTNET, so we don't need to do it manually
    if (chainId == 31337) {
        const vrfCoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock")
        await vrfCoordinatorV2Mock.addConsumer(subscriptionId, CoinFlip.address)
        log("adding consumer...")
        log("Consumer added!")
    }

    //VERIFICATION OF CONTRACT'S ABI ON POLYSCAN
    if (
        !developmentChains.includes(network.name) &&
        process.env.POLYSCAN_API_KEY &&
        chainId == 80001
    ) {
        log("Verifying the contract on matic mumbai...")
        await verify(CoinFlip.address, args)
    }

    //VERIFICATION OF CONTRACT'S ABI ON ETHERSCAN
    if (
        !developmentChains.includes(network.name) &&
        process.env.ETHERSCAN_API_KEY &&
        chainId == 11155111
    ) {
        log("Verifying the contract on sepolia network...")
        await verify(CoinFlip.address, args)
    }

    //VERIFICATION OF CONTRACT'S ABI ON ETHERSCAN
    if (
        !developmentChains.includes(network.name) &&
        process.env.ETHERSCAN_API_KEY &&
        chainId == 1
    ) {
        log("Verifying the contract on ethereum mainnet...")
        await verify(CoinFlip.address, args)
    }
    log("---------------------------------")
}

module.exports.tags = ["all", "coinflip"]
