const AccessContract = artifacts.require("SimpleWriteAccessController");
module.exports = function (deployer) {
  deployer.deploy(AccessContract);
};
