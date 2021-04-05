const VaultRegistry = artifacts.require("VaultRegistry");


module.exports = async (callback) => {
  try {
    const len = process.argv.length;
    const vaultRegistryAddress = process.argv[len - 3];
    const interval = process.argv[len - 2];
    const reward = process.argv[len - 1];

    const vaultRegistry = await VaultRegistry.at(vaultRegistryAddress);
    await vaultRegistry.addLock(interval, reward);
  } catch (e) {
    console.error(e);
  }
  callback();
}
