const VaultRegistry = artifacts.require("VaultRegistry");

module.exports = function (deployer) {
  deployer.deploy(VaultRegistry);
};
