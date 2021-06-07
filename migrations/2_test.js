const TestContract = artifacts.require("Test");
module.exports = function (deployer) {
  deployer.deploy(TestContract);
};
