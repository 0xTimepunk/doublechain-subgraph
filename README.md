# Briing


## Runing the Subgraph

For more information see the docs on https://thegraph.com/docs/

### Prerequisites

Instalation made with yarn, adjust for npm.

ganache-cli, truffle-cli, @graphprotocol/graph-cli, graph-node, docker, docker-compose

- Run `yarn global add ganache-cli truffle-cli @graphprotocol/graph-cli graph-node`
- [Docker Instalation](https://docs.docker.com/install/linux/docker-ce/debian/)
- Run `git clone https://github.com/graphprotocol/graph-node/` (check setup instructions for docker version)

### Running a Local Graph Node

1. On the p2pchain folder, run `yarn`
2. Run a blockchain, e.g. ganache, in a separate terminal in the p2pchain folder: `yarn ganache`
3. Deploy contracts with `yarn truffle`. No need to update address in the subgraph configuration (if ganache is running with deterministic (-d) parameter)
4. Generate subgraph typescript files with `yarn codegen`
5. In a third terminal, on the graph-node folder, run `cd docker && docker-compose up`
6. Create and deploy the subgraph to graph-node with `yarn create-local && yarn deploy-local` on the first terminal
7. Run examples queries against [GraphiQL](http://127.0.0.1:8000/subgraphs/name/j-mars/briing)