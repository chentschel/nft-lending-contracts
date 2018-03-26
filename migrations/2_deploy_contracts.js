// var CryptoCountries = artifacts.require("./CryptoCountries.sol");
// var CryptoCelebrities = artifacts.require("./CryptoCelebrities.sol");
// var Players = artifacts.require("./PlayerToken.sol");

var Lender = artifacts.require("./Lender.sol")
var Marketplace = artifacts.require("./Marketplace.sol")

module.exports = function (deployer) {
  // deployer.deploy(CryptoCelebrities);
  // deployer.deploy(CryptoCountries);
  deployer.deploy(Marketplace)
  deployer.deploy(Lender)
}
