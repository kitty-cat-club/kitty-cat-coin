const { ethers } = require("hardhat");

(async () => {
  try {
    const TokenFactory = await ethers.getContractFactory("FrogCoin");
    console.log("Deploying...");
    let token = await TokenFactory.deploy(
      "Frog Coin",
      "FROG",
      ethers.utils.parseUnits("2000000000000", 18),
      "0xF0ce59c87592867da729AEb1AF728B9a988DecE9",
      15
    );
    token = await token.deployed();
    console.log(token.address);
  } catch (error) {
    console.log(error);
  }
})();
