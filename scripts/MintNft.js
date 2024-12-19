const { ethers, getNamedAccounts } = require("hardhat")

async function mintNFT() {
    console.log("Connecting to the contracts...")
    const { deployer } = await getNamedAccounts()
    const amount = ethers.utils.parseEther("50")
    const contract = await ethers.getContract("GameCoins")
    console.log("Connected!")
    console.log("Minting the nfts...")
    const mint = await contract.nftMint({ value: amount })
    await mint.wait(1)
    const balance = await contract.balanceOf(deployer)
    console.log(`${balance} NFT has been succesfully minted!`)
}

mintNFT()
    .then(() => process.exit(0))
    .catch((e) => {
        console.error(e)
        process.exit(1)
    })
