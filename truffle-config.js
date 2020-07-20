const path = require("path");
module.exports = {
  plugins: ["truffle-security"],
  contracts_build_directory: path.join(__dirname, "src/abi"),
  networks: {
    ganachecli: {
      host: "127.0.0.1",
      port: 8545,
      network_id: "*",
      websockets: true,
    },
    ganachegui: {
      host: "127.0.0.1",
      port: 7545,
      network_id: "*",
      websockets: true,
    },
  },
  compilers: {
    solc: {
      version: "0.5.17",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200,
        },
      },
    },
  },
};
