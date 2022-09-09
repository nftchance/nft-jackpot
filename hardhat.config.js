require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-ethers");
require("hardhat-gas-reporter");

// make sure process env is ready
require("dotenv").config();

console.log('process.env.ALCHEMY_API_KEY', process.env.ALCHEMY_API_KEY)

module.exports = {
  solidity: "0.8.16",
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 31337,
      gas: "auto",
      gasPrice: "auto",
      saveDeployments: false,
      forking: {
        url: `https://eth-rinkeby.alchemyapi.io/v2/${process.env.ALCHEMY_API_KEY}`,
      },
    },
  },
  gasReporter: {
    currency: 'USD',
    gasPrice: 60,
    coinmarketcap: '9896bb6e-1429-4e65-8ba8-eb45302f849b',
    showMethodSig: true,
    showTimeSpent: true,
  },
};
