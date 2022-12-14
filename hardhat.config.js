require("@nomiclabs/hardhat-ethers");

require("dotenv").config();

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    version: '0.8.17',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true,
    },
  },
  networks: {
    bitgert_mainnet: {
      url: "https://nodes.vefinetwork.org/bitgert",
      accounts: [process.env.PRIVATE_KEY],
      chainId: 32520,
      gas: 7100000,
      gasPrice: 20000000000
    }
  }
};
