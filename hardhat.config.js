require("@nomiclabs/hardhat-ethers");

require("dotenv").config();

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: "0.8.17",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    bitgert_mainnet: {
      url: "https://nodes.vefinetwork.org/bitgert",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 32520
    },
    okx_mainnet: {
      url: "https://exchainrpc.okex.org",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 66
    },
    astar_mainnet: {
      url: "https://nodes.vefinetwork.org/astar",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 592
    }
  }
};
