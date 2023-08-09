const BattleshipMigrations = artifacts.require("BattleshipMigrations");
const Battleship = artifacts.require("Battleship");
const BattleshipStorage = artifacts.require("BattleshipStorage");

module.exports = function (deployer) {
  deployer.deploy(BattleshipMigrations);
    return deployer.deploy(BattleshipStorage, true).then(function(){
      return deployer.deploy(Battleship, BattleshipStorage.address);
    });

};
