const VaultRegistry = artifacts.require("VaultRegistry");


module.exports = async (callback) => {
  try {
    const len = process.argv.length;
    const vaultRegistryAddress = process.argv[len - 2];
    const rewardValue = process.argv[len - 1]; // IN USDT

    const vaultRegistry = await VaultRegistry.at(vaultRegistryAddress);
    await vaultRegistry.setRewardValue(web3.utils.toWei(rewardValue));
  } catch (e) {
    console.error(e);
  }
  callback();
}