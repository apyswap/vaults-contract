require('dotenv').config();
const HDWalletProvider = require("@truffle/hdwallet-provider");

module.exports = {
  networks: {
    development: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*",
    },
    goerli: {
      provider: () => {
        return new HDWalletProvider({
          privateKeys: [process.env.GOERLI_PK], 
          providerOrUrl: 'https://goerli.infura.io/v3/' + process.env.INFURA_KEY
          });
      },
      network_id: '5', // eslint-disable-line camelcase
      gasPrice: 10e9,
    },
    mainnet: {
      provider: function() {
        return new HDWalletProvider({
          privateKeys: [process.env.MAINNET_PK], 
          providerOrUrl: 'https://mainnet.infura.io/v3/' + process.env.INFURA_KEY
          });
      },
      gas: 2000000,
      gasPrice: 150e9,
      network_id: 1
    }
  },
  compilers: {
    solc: {
      version: "^0.6",  
    }
  }
};
