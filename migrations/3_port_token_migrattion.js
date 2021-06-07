const PortContract = artifacts.require("MockPortToken");
module.exports = function (deployer) {
  deployer.deploy(PortContract);
};
