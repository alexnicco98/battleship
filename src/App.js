import React, { useState, useEffect } from "react";
import { Battleship } from "./abi/abi1";
import { BattleshipStorage } from "./abi/abi2";
import Web3 from "web3";
import "./App.css";
import "./IntBattleshipStruct.sol";

/* New-Item -ItemType SymbolicLink -Path "." -name IntBattleshipStruct.sol -Target "C:\Users\anicc\Documents\Desktop\P2P\project\battleship\storage-lab\contracts\libraries\IntBattleshipStruct.sol"
*/

/*using IntBattleshipStruct for IntBattleshipStruct.BattleModel;
    using IntBattleshipStruct for IntBattleshipStruct.PlayerModel;
    using IntBattleshipStruct for IntBattleshipStruct.ShipPosition;
    using IntBattleshipStruct for IntBattleshipStruct.GamePhaseDetail;
    using IntBattleshipStruct for IntBattleshipStruct.LobbyModel;*/

// Access our wallet inside of our dapp
const web3 = new Web3(Web3.givenProvider);
// Contract address of the deployed smart contract

// Load Battleship contract ABI and address
//const fs = require('fs');
// $truffle console 
// and after: YourContractName.deployed().then(instance => instance.address)
/*const contract1 = JSON.parse(fs.readFileSync('./build/contracts/Battleship.json', 'utf8'));
const contract2 = JSON.parse(fs.readFileSync('./build/contracts/BattleshipStorage.json', 'utf8'));
*/
const contract1 = '0x909f2d3aecE05cEEeF8b41DA08A4e479170eAcf3';
const contract2 = '0x7EaFd6Ebc7A3bc673F0bafcf5e49c6A0db4B0B9d';
const BattleshipContract = new web3.eth.Contract(Battleship, contract1);
const BattleshipStorageContract = new web3.eth.Contract(BattleshipStorage, contract2);

async function App() {
  const [gameStarted, setGameStarted] = useState(false);
  const [winner, setWinner] = useState(null);
  const [playerBoard, setPlayerBoard] = useState([]);
  const [opponentBoard, setOpponentBoard] = useState([]);
  const accounts = await window.ethereum.enable();
  let playerOne = accounts[0];
  let playerTwo = accounts[1];
  // Initialize player boards with ship positions
  const playerOnePositions = [
    { shipLength: 1, axisX: 1, axisY: 1, direction: ShipDirection.Horizontal },
    { shipLength: 2, axisX: 2, axisY: 2, direction: IntBattleshipStruct.ShipDirection.Vertical }
  ];
  const playerTwoPositions = [
    { shipLength: 1, axisX: 0, axisY: 1, direction: IntBattleshipStruct.ShipDirection.Horizontal },
    { shipLength: 2, axisX: 3, axisY: 0, direction: IntBattleshipStruct.ShipDirection.Vertical }
  ];

  // Initialize contracts and other state variables here

  useEffect(() => {
    // Load contracts and initialize game state here

    playerBoard = initializePlayerBoard(playerOnePositions);
    opponentBoard = initializePlayerBoard(playerTwoPositions);

    setPlayerBoard(playerBoard);
    setOpponentBoard(opponentBoard);
  }, []);

  // Define a function to initialize a player's board with ship positions
  const initializePlayerBoard = (shipPositions) => {
    // Initialize an empty 2D board
    const board = Array(10).fill(null).map(() => Array(10).fill(null));

    // Place ships on the board based on ship positions
    shipPositions.forEach((ship) => {
      const { shipLength, axisX, axisY, direction } = ship;

      for (let i = 0; i < shipLength; i++) {
        if (direction === IntBattleshipStruct.ShipDirection.Horizontal) {
          board[axisY][axisX + i] = "S"; // "S" represents a ship
        } else {
          board[axisY + i][axisX] = "S";
        }
      }
    });

    return board;
  };
  
  /*// Positions for player one and two
  let playerOnePositions = [
    { shipLength: 1, axisX: 1, axisY: 1, direction: ShipDirection.Horizontal },
    { shipLength: 2, axisX: 2, axisY: 2, direction: ShipDirection.Vertical }
  ];
  let playerTwoPositions = [
      { shipLength: 1, axisX: 0, axisY: 1, direction: ShipDirection.Horizontal },
      { shipLength: 2, axisX: 3, axisY: 0, direction: ShipDirection.Vertical }
  ];*/

  // Positions attacked by player one and two
  let positionsAttackedByPlayerOne = [{axisX: 0, axisY: 1}, {axisX: 0, axisY: 3},
      {axisX: 2, axisY: 2}, {axisX: 3, axisY: 3}];
  let positionsAttackedByPlayerTwo = [{axisX: 0, axisY: 0}, {axisX: 2, axisY: 2}, 
      {axisX: 2, axisY: 3}, {axisX: 1, axisY: 1}];
  
  // Merkle tree leaves for player one and player two
  let playerOneLeaves;
  let playerTwoLeaves;

  // Merkle roots for both players
  let playerOneRootHash;
  let playerTwoRootHash;
  
  // Convert the player positions objects to individual arguments
  const playerOneShipLengths = playerOnePositions.map(ship => ship.shipLength);
  const playerOneAxisXs = playerOnePositions.map(ship => ship.axisX);
  const playerOneAxisYs = playerOnePositions.map(ship => ship.axisY);
  const playerOneDirections = playerOnePositions.map(ship => ship.direction);

  const playerTwoShipLengths = playerTwoPositions.map(ship => ship.shipLength);
  const playerTwoAxisXs = playerTwoPositions.map(ship => ship.axisX);
  const playerTwoAxisYs = playerTwoPositions.map(ship => ship.axisY);
  const playerTwoDirections = playerTwoPositions.map(ship => ship.direction);

  // Set ship positions for player one
  await BattleshipStorageContract.methods.setShipPositions(
      playerOneShipLengths,
      playerOneAxisXs,
      playerOneAxisYs,
      playerOneDirections,
      playerOne,
  );

  // Set ship positions for player two
  await BattleshipStorageContract.methods.setShipPositions(
      playerTwoShipLengths,
      playerTwoAxisXs,
      playerTwoAxisYs,
      playerTwoDirections,
      playerTwo,
  );

  // Create Merkle tree leaves for player one and player two
  playerOneLeaves = await BattleshipStorageContract.methods.getMerkleTreeLeaves(playerOne);
  playerTwoLeaves = await BattleshipStorageContract.methods.getMerkleTreeLeaves(playerTwo);
  
  console.log("player One leaves:", playerOneLeaves.toString());
  console.log("-----------------------------------------------");
  console.log("player Two leaves:", playerTwoLeaves.toString());

  await BattleshipStorageContract.methods.calculateMerkleRoot(playerOneLeaves, playerOne);
  await BattleshipStorageContract.methods.calculateMerkleRoot(playerTwoLeaves, playerTwo);

  // Calculate Merkle roots for both players
  playerOneRootHash = await BattleshipStorageContract.methods.getMerkleRoot(playerOne);
  playerTwoRootHash = await BattleshipStorageContract.methods.getMerkleRoot(playerTwo);
  let gamePhase = IntBattleshipStruct.GamePhase.Placement;
  let battleId;

  const startGame = async () => {
    // Initialize the game and start it
    try {
      // Player One
      let valueInWei = 100000000000000;
      let result;

      result = await BattleshipContract.methods.createLobby(gamePhase, playerOneRootHash, 
        { from: playerOne, value: valueInWei });

      // Player Two
      valueInWei = 100000000000000;
      battleId = await BattleshipContract.methods.joinLobby(playerOne, gamePhase, playerTwoRootHash, 
        { from: playerTwo, value: valueInWei });

      setGameStarted(true);
    } catch (error) {
      console.error("Error starting the game:", error);
    }
  };

  // Define a function to handle attacks
  const performAttack = async () => {
    try {
      let attackingPosition = positionsAttackedByPlayerTwo[0]; 
      let currentPositionLeafAttackedByPlayerTwo = await BattleshipStorageContract.methods.
          getMerkleTreeLeaf(playerOne, attackingPosition.axisX, attackingPosition.axisY);
      let proof = await BattleshipStorageContract.methods.getMerkleTreeProof(playerOne);
      let proofleaf = await BattleshipStorageContract.methods.generateProof(
          playerOne, attackingPosition.axisY, attackingPosition.axisX);
      // Get the current state of the battle
      let initialBattleState = await BattleshipStorageContract.methods.getBattle(battleId);

      // playerTwo perform the 1° attack
      let attackResult = await BattleshipContract.methods.attack(
        battleId, proofleaf, attackingPosition.axisX, attackingPosition.axisY,
        { from: playerTwo });

      // Get the updated state of the battle
      let updatedBattleState = await BattleshipStorageContract.methods.getBattle(battleId);

      // ------------------------------------------------------------------
      // playerOne perform the 1° attack
      attackingPosition = positionsAttackedByPlayerOne[0];
      let currentPositionLeafAttackedByPlayerOne = await BattleshipStorageContract.methods.
          getMerkleTreeLeaf(playerTwo, attackingPosition.axisX, attackingPosition.axisY);
      proof = await BattleshipStorageContract.methods.getMerkleTreeProof(playerTwo);
      proofleaf = await BattleshipStorageContract.methods.generateProof(
          playerTwo, attackingPosition.axisY, attackingPosition.axisX);
      proof = await BattleshipStorageContract.methods.getMerkleTreeProof(playerOne);

      // Get the current state of the battle
      initialBattleState = await BattleshipStorageContract.methods.
      getLastPlayTimeByBattleId(battleId);

      // Perform the attack
      attackResult = await BattleshipContract.methods.attack(
      battleId, proofleaf, attackingPosition.axisX, attackingPosition.axisY, 
      { from: playerOne });

      // ------------------------------------------------------------------
      // playerTwo perform the 2° attack
      attackingPosition = positionsAttackedByPlayerTwo[1];
      currentPositionLeafAttackedByPlayerTwo = await BattleshipStorageContract.methods.
          getMerkleTreeLeaf(playerOne, attackingPosition.axisX, attackingPosition.axisY);
      proof = await BattleshipStorageContract.methods.getMerkleTreeProof(playerOne);
      proofleaf = await BattleshipStorageContract.methods.generateProof(
          playerOne, attackingPosition.axisY, attackingPosition.axisX);

      attackResult = await BattleshipContract.methods.attack(
        battleId, proofleaf, attackingPosition.axisX, attackingPosition.axisY,
        { from: playerTwo });

      // ------------------------------------------------------------------
      // playerOne perform the 2° attack
      attackingPosition = positionsAttackedByPlayerOne[1];
      currentPositionLeafAttackedByPlayerOne = await BattleshipStorageContract.methods.
          getMerkleTreeLeaf(playerTwo, attackingPosition.axisX, attackingPosition.axisY);
      proofleaf = await BattleshipStorageContract.methods.generateProof(
      playerTwo, attackingPosition.axisY, attackingPosition.axisX);

      attackResult = await BattleshipContract.methods.attack(
        battleId, proofleaf, attackingPosition.axisX, attackingPosition.axisY, 
        { from: playerOne });

      // ------------------------------------------------------------------
      // playerTwo perform the 3° attack
      attackingPosition = positionsAttackedByPlayerTwo[2];
      currentPositionLeafAttackedByPlayerTwo = await BattleshipStorageContract.methods.
          getMerkleTreeLeaf(playerOne, attackingPosition.axisX, attackingPosition.axisY);
      proofleaf = await BattleshipStorageContract.methods.generateProof(
          playerOne, attackingPosition.axisY, attackingPosition.axisX);

      attackResult = await BattleshipContract.methods.attack(
          battleId, proofleaf, attackingPosition.axisX, attackingPosition.axisY, 
          { from: playerTwo });

      // ------------------------------------------------------------------
      // playerOne perform the 3° attack
      attackingPosition = positionsAttackedByPlayerOne[2];
      currentPositionLeafAttackedByPlayerOne = await BattleshipStorageContract.methods.
          getMerkleTreeLeaf(playerTwo, attackingPosition.axisX, attackingPosition.axisY);
      proofleaf = await BattleshipStorageContract.methods.generateProof(
          playerTwo, attackingPosition.axisY, attackingPosition.axisX);

      attackResult = await BattleshipContract.methods.attack(
          battleId, proofleaf, attackingPosition.axisX, attackingPosition.axisY,
          { from: playerOne });

      // ------------------------------------------------------------------
      // playerTwo perform the 4° attack
      attackingPosition = positionsAttackedByPlayerTwo[3];
      currentPositionLeafAttackedByPlayerTwo = await BattleshipStorageContract.methods.
          getMerkleTreeLeaf(playerOne, attackingPosition.axisX, attackingPosition.axisY);
      proofleaf = await BattleshipStorageContract.methods.generateProof(
          playerOne, attackingPosition.axisY, attackingPosition.axisX);

      attackResult = await BattleshipContract.methods.attack(
          battleId, proofleaf, attackingPosition.axisX, attackingPosition.axisY, 
          { from: playerTwo });
    } catch (error) {
      console.error("Error performing attack:", error);
    }
  };

  /*updatedBattleState = await BattleshipStorageContract.methods.getBattle(battleId);

  // Check if there is a winner
  if (updatedBattleState.isCompleted) {
      console.log("Winner address", updatedBattleState.winner);
  }*/
  
  // Render the game board for a player
  const renderPlayerBoard = () => {
    return (
      <div className="board">
        {playerBoard.map((row, rowIndex) => (
          <div key={rowIndex} className="row">
            {row.map((cell, cellIndex) => (
              <div key={cellIndex} className={`cell ${cell === "X" ? "hit" : "miss"}`}>
                {cell === "X" ? (
                  <img src="hit-image.png" alt="Hit" />
                ) : cell === "O" ? (
                  <img src="miss-image.png" alt="Miss" />
                ) : null}
              </div>
            ))}
          </div>
        ))}
      </div>
    );
  };

  return (
  <div className="App">
    <h1>Battleship Game</h1>

    {!gameStarted ? (
      <button onClick={startGame}>Start Game</button>
    ) : (
      <>
        <h2>Game in Progress</h2>

        {/* Render player boards */}
        <div className="player-board">
          {renderPlayerBoard()}
        </div>
        <div className="opponent-board">
          {/* Render opponent's board (if needed) */}
        </div>

        {winner && (
          <div className="winner-popup">
            <h3>Winner: {winner}</h3>
            {/* Add other content or actions for the winner popup */}
          </div>
        )}

        {/* Add UI for player actions, e.g., performing attacks */}
      </>
    )}
  </div>
);

}

export default App;