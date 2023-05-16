const { ethers } = require("hardhat");

(async () => {
  try {
    const TokenFactory = await ethers.getContractFactory("KittyCatCoin");
    console.log("Deploying...");
    let token = await TokenFactory.deploy(
      "Kitty Cat Coin",
      "CAT",
      ethers.utils.parseUnits("200000000000000", 18),
      "0xC09473e26C150700a57aD63d3576eea44D510a3C",
      15
    );
    token = await token.deployed();
    console.log(token.address);
  } catch (error) {
    console.log(error);
  }
})();
