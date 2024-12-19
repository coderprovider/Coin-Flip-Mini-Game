const { getNamedAccounts, ethers } = require("hardhat")

async function Deposit() {
    console.log("Connecting to the contracts...")
    const { deployer } = await getNamedAccounts()
    const amount = ethers.utils.parseEther("0.1")
    const contract = await ethers.getContract("Gameplay", deployer)
    console.log("Connected!")
    console.log("Depositing funds...")
    const deposit = await contract.deposit({ value: amount })
    await deposit.wait(1)
    console.log("Funds have been deposited!")
}

Deposit()
    .then(() => process.exit(0))
    .catch((e) => {
        console.error(e)
        process.exit(1)
    })
