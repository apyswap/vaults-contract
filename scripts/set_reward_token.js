const VaultRegistry = artifacts.require("VaultRegistry");


module.exports = async (callback) => {
  try {
    const len = process.argv.length;
    const vaultRegistryAddress = process.argv[len - 2];
    const rewardTokenAddress = process.argv[len - 1];

    const vaultRegistry = await VaultRegistry.at(vaultRegistryAddress);
    await vaultRegistry.setReward(rewardTokenAddress);
  } catch (e) {
    console.error(e);
  }
  callback();
}
