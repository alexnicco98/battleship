const BattleshipMigrations = artifacts.require("BattleshipMigrations");
const Battleship = artifacts.require("Battleship");
const BattleshipStorage = artifacts.require("BattleshipStorage");
//const BattleshipLogic = artifacts.require("BattleshipLogic");

module.exports = function (deployer) {
  deployer.deploy(BattleshipMigrations);
 // deployer.deploy(BattleshipLogic).then(function(){
  // , BattleshipLogic.address
    return deployer.deploy(BattleshipStorage, true).then(function(){
      //, BattleshipLogic.address
      return deployer.deploy(Battleship, BattleshipStorage.address);
    });
  //});
};
