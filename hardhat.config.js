require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
require("dotenv").config();

const accounts = [process.env.PRIVATE_KEY];

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "mainnet",
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
      accounts: [
        "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
      ],
    },
    hardhat: {},
    metaflap: {
      url: "http://139.177.189.239:8545",
      accounts: [
        "0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80",
      ],
    },
    testnet: {
      url: "https://data-seed-prebsc-1-s1.bnbchain.org:8545",
      chainId: 97,
      gasPrice: 35000000000,
      accounts,
    },
    mainnet: {
      url: "https://bsc-dataseed.bnbchain.org/",
      chainId: 56,
      gasPrice: 35000000000,
      accounts,
    },
  },
  solidity: {
    version: "0.8.24",
    settings: {
      optimizer: {
        enabled: true,
      },
    },
  },
  etherscan: {
    apiKey: {
      bsc: "DCV6FKHS2PXY5EZCB7XU5U4JV1H4NWWWBX",
      bscTestnet: "DCV6FKHS2PXY5EZCB7XU5U4JV1H4NWWWBX",
    },
  },
};
