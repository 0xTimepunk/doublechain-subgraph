// ganache-gui mnemonic sea huge rural lock garment antenna seek spatial glimpse name defy elder note: this mnemonic is not secure; don't use it on a public blockchain.
const HDWalletProvider = require("@truffle/hdwallet-provider");
const mnemonic = "surprise sweet upset clock glory used motor hover cross sight cry evidence"

const path = require("path");
module.exports = {

  plugins: ["truffle-security"],

  contracts_build_directory: path.join(__dirname, "src/abi"),
  networks: {
    ganachecli: {
      host: '127.0.0.1',
      port: 8545,
      network_id: '*',
      websockets: true
    },
    ganachegui: {
      host: '127.0.0.1',
      port: 7545,
      network_id: '*',
      websockets: true
    },
    briing: {
      provider: () => new HDWalletProvider(mnemonic, "https://demo:briing@briing.io/eth"),
      network_id: '53006',
      gas: "0x7a1200"
    }
  },
  compilers: {
    solc: {
      version: "0.5.17",
      settings: {
        optimizer: {
          enabled: true,
          runs: 200000
        }
      }
    }
  }
};
