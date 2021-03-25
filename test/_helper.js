const PREFIX = "Returned error: VM Exception while processing transaction:";

class _helper {
  static async tryCatch(promise, errText, errType = "revert") {
    try {
      await promise;
      throw null;
    }
    catch (error) {
      assert(error, "Expected an error but did not get one");
      if (errType) {
        errType = " " + errType;
      }
      let expected = `${PREFIX}${errType} ${errText}`;
      assert(error.message.startsWith(expected), `Expected an error starting with '${expected}' but got '${error.message}' instead`);
    }
  };
}

module.exports = {Helper: _helper};
