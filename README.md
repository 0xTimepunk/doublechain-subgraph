# Doublechain Subgraph [Briing]
Fostering customer bargaining and e-procurement through a decentralised marketplace on the blockchain

Doublechain is a customer-push e-marketplace built on top of Ethereum, where customers can aggregate their proposals, and suppliers try to outcompete each other in reverse auction bids to fulfil the order. Furthermore, smart contracts make it possible to automate many operational activities such as payment escrows/release upon delivery confirmation, increasing the efficiency along the supply chain. The implementation of this network is expected to improve market efficiency by reducing transaction costs, time delays and information asymmetry. Furthermore, concepts such as increased bargaining power and economies of scale, and their effects in buyer-supplier relationships, are also explored.

## Runing the Subgraph

For more information see the docs on https://thegraph.com/docs/, a distributed blockchain event indexing engine that facilitates data querying.

### Prerequisites

Instalation made with yarn, adjust for npm.

ganache-cli, truffle-cli, @graphprotocol/graph-cli, graph-node, docker, docker-compose

- Run `yarn global add ganache-cli truffle-cli @graphprotocol/graph-cli graph-node`
- [Docker Instalation](https://docs.docker.com/install/linux/docker-ce/debian/)
- Run `git clone https://github.com/graphprotocol/graph-node/` (check setup instructions for docker version)

### Compile the smart contracts and run the graph's blockchain indexing engine

1. On the p2pchain folder, run `yarn`.
2. Run a blockchain, e.g. ganache, in a separate terminal in the p2pchain folder: `yarn ganache`.
3. Deploy contracts with `yarn truffle`. Update deployed contract's addresses in the subgraph.yaml file.
4. Generate subgraph typescript files with `yarn codegen`.
5. In a third terminal, on the graph-node cloned folder, run `cd docker && docker-compose up`.
6. Create and deploy the subgraph to graph-node with `yarn create-local && yarn deploy-local` on the first terminal
7. Run examples queries against [GraphiQL](http://127.0.0.1:8000/subgraphs/name/doublechain/subgraph) (There is an example query within docs/example.graphql. Must run some transactions first. You can mock some data with `yarn mocklists && yarn mockbuyers`)