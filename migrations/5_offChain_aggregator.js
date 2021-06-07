const AccessContract = artifacts.require("SimpleWriteAccessController");
const PortContract = artifacts.require("MockPortToken");
const OffChainAggregator = artifacts.require("AccessControlledOffchainAggregator");
module.exports = function (deployer) {


    let maximumGasPrice = 1;
    let reasonableGasPrice = 10;
    let microPortPerEth = 1000000;
    let portGweiPerObservation = 500;
    let portGweiPerTransmission = 300;
    let port = PortContract.address;
    let billingAccessController = AccessContract.address;
    let requesterAccessController = AccessContract.address;
    let decimals = 8;
    let description = "query something";

  deployer.deploy(OffChainAggregator, maximumGasPrice, reasonableGasPrice, microPortPerEth, portGweiPerObservation, portGweiPerTransmission, 
    port, billingAccessController, requesterAccessController, decimals, description);
};
