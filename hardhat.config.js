require("@nomiclabs/hardhat-ethers");

require("dotenv").config();

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: "0.8.17",
  networks: {
    bitgert_mainnet: {
      url: "https://rpc.icecreamswap.com",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 32520
    }
  }
};
