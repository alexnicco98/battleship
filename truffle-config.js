module.exports = {
  /**
   * Networks define how you connect to your ethereum client and let you set the
   * defaults web3 uses to send transactions. If you don't specify one truffle
   * will spin up a development blockchain for you on port 9545 when you
   * run `develop` or `test`. You can ask a truffle command to use a specific
   * network from the command line, e.g
   *
   * $ truffle test --network <network-name>
   */

  networks: {
    // Useful for testing. The `development` name is special - truffle uses it by default
    // if it's defined here and no other network is specified at the command line.
    // You should run a client (like ganache-cli, geth or parity) in a separate terminal
    // tab if you use this network and you must also set the `host`, `port` and `network_id`
    // options below to some value.
    //
    development: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 7545,            // Standard Ethereum port (default: none)
      network_id: "*",       // Any network (default: none)
      gas: 8500000  ,        // Gas sent with each transaction (default: ~6700000)
      gasPrice: 2500000000   // 2.5 gwei (in wei) (default: 100 gwei)
    // from: <address>,      // Account to send txs from (default: accounts[0])
    // websocket: true       // Enable EventEmitter interface for web3 (default: false)

    }
  },

  // Set default mocha options here, use special reporters etc.
  /*mocha: {
    reporter: 'eth-gas-reporter',
    //reporterOptions : { gasPrice }, // See options below
    timeout: 100000
  },*/

  // Configure your compilers
  compilers: {
    solc: {
       version: "^0.8.13",    // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      settings: {          // See the solidity docs for advice about optimization and evmVersion
       optimizer: {
         enabled: true,
         runs: 200
       },
       //evmVersion: 'london',
       viaIR: true, // Enable VIA-IR code generation
       evmVersion: "byzantium"
      }
    }
  },

  // Truffle DB is currently disabled by default; to enable it, change enabled: false to enabled: true
  //
  // Note: if you migrated your contracts prior to enabling this field in your Truffle project and want
  // those previously migrated contracts available in the .db directory, you will need to run the following:
  // $ truffle migrate --reset --compile-all

  db: {
    enabled: false
  },
  
  plugins: ["truffle-contract-size"]
};