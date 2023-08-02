/*const Battleship = artifacts.require("Battleship");
const truffleAssert = require('truffle-assertions');


contract('Battleship', (accounts) => {
  let battleship;

  beforeEach(async () => {
    battleship = await Battleship.new();
  });

  it('should add a player to the game', async () => {
    const boardHash = web3.utils.sha3('test');
    await battleship.addPlayer(boardHash, { from: accounts[0] });
    const player = await battleship.players.call(accounts[0]);
    assert.equal(player.boardHash, boardHash);
  });

  //   await battleship.addPlayer(boardHash, { from: accounts[1] });

  it('should place a ship on the player\'s board', async () => {
    const boardHash = web3.utils.sha3('test');
    await battleship.addPlayer(boardHash, { from: accounts[0] });
  
    const player = await battleship.players.call(accounts[0]);
    console.log("Player object:", player);
  
    await battleship.placeShip(0, 0, 1, { from: accounts[0] });
    const updatedPlayer = await battleship.players.call(accounts[0]);
    console.log("Updated player object:", updatedPlayer);
  
    assert.equal(updatedPlayer.ships.length, 1, "The ship was not placed on the player's board.");
  });
  

  it('should not allow a ship to be placed outside the bounds of the board', async () => {
    await battleship.addPlayer(web3.utils.sha3('test'), { from: accounts[0] });
    await truffleAssert.reverts(battleship.placeShip(4, 0, 1, { from: accounts[0] }));
  });

  it('should not allow a ship to be placed with an invalid length', async () => {
    await battleship.addPlayer(web3.utils.sha3('test'), { from: accounts[0] });
    await truffleAssert.reverts(battleship.placeShip(0, 0, 5, { from: accounts[0] }));
  });

  it('should not allow a player to place more ships than allowed', async () => {
    await battleship.addPlayer(web3.utils.sha3('test'), { from: accounts[0] });
    await battleship.placeShip(0, 0, 1, { from: accounts[0] });
    await truffleAssert.reverts(battleship.placeShip(1, 0, 1, { from: accounts[0] }));
  });

  // Add more tests here...
});*/