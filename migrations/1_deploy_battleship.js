const Battleship = artifacts.require("Battleship");
const BattleshipStorage = artifacts.require("BattleshipStorage");

module.exports = function (deployer) {
  return deployer.deploy(BattleshipStorage).then(function(){
    return deployer.deploy(Battleship, BattleshipStorage.address);
  });
};
