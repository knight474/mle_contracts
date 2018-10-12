module.exports = {
  networks: {
     development: {
     host: "127.0.0.1",
     port: 7545,
     network_id: "*", // Match any network id,
     gas: 79999000, // Block Gas Limit same as latest on Mainnet https://ethstats.net/
    },
    ropsten: {
      host: "127.0.0.1",
      port: 8545,
      network_id: 3,
    }
  },
  mocha: {
    enableTimeouts: false
  },
  solc: {
    optimizer: {
      enabled: true,
      runs: 200
    }
  }
};