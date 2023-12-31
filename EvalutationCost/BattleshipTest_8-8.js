const Battleship = artifacts.require("Battleship");
const IntBattleshipStruct = artifacts.require("IntBattleshipStruct");
const BattleshipStorage = artifacts.require("BattleshipStorage");
const GamePhase = IntBattleshipStruct.GamePhase;
const ShipDirection = IntBattleshipStruct.ShipDirection;
const ShipPosition = IntBattleshipStruct.ShipPosition;


contract("Battleship", accounts => {
    let battleshipInstance;
    let battleshipStorageInstance;
    let battleId;
    let playerOne = accounts[0];
    let playerTwo = accounts[1];

    console.log("player One adrress: ", playerOne);
    console.log("player Two adrress: ", playerTwo);

    // Positions for player one and two
    let playerOnePositions = [
        { shipLength: 1, axisX: 1, axisY: 1, direction: ShipDirection.Horizontal },
        { shipLength: 2, axisX: 6, axisY: 3, direction: ShipDirection.Vertical },
        { shipLength: 3, axisX: 3, axisY: 3, direction: ShipDirection.Vertical },
        { shipLength: 4, axisX: 2, axisY: 7, direction: ShipDirection.Horizontal }
    ];
    let playerTwoPositions = [
        { shipLength: 1, axisX: 7, axisY: 7, direction: ShipDirection.Horizontal },
        { shipLength: 2, axisX: 2, axisY: 5, direction: ShipDirection.Vertical },
        { shipLength: 3, axisX: 0, axisY: 4, direction: ShipDirection.Horizontal },
        { shipLength: 4, axisX: 5, axisY: 1, direction: ShipDirection.Vertical }
    ];

    // Positions attacked by player one and two
    let positionsAttackedByPlayerOne = [
        // Player one misses on all positions until the last step
        { axisX: 0, axisY: 0 },
        { axisX: 0, axisY: 1 },
        { axisX: 0, axisY: 2 },
        { axisX: 0, axisY: 3 },
        { axisX: 0, axisY: 5 },
        { axisX: 0, axisY: 6 },
        { axisX: 0, axisY: 7 },
        { axisX: 1, axisY: 0 },
        { axisX: 1, axisY: 1 },
        { axisX: 1, axisY: 2 },
        { axisX: 1, axisY: 3 },
        { axisX: 1, axisY: 5 },
        { axisX: 1, axisY: 6 },
        { axisX: 1, axisY: 7 },
        { axisX: 2, axisY: 0 },
        { axisX: 2, axisY: 1 },
        { axisX: 2, axisY: 2 },
        { axisX: 2, axisY: 3 },
        { axisX: 2, axisY: 7 },
        { axisX: 3, axisY: 0 },
        { axisX: 3, axisY: 1 },
        { axisX: 3, axisY: 2 },
        { axisX: 3, axisY: 3 },
        { axisX: 3, axisY: 4 },
        { axisX: 3, axisY: 5 },
        { axisX: 3, axisY: 6 },
        { axisX: 3, axisY: 7 },
        { axisX: 4, axisY: 0 },
        { axisX: 4, axisY: 1 },
        { axisX: 4, axisY: 2 },
        { axisX: 4, axisY: 3 },
        { axisX: 4, axisY: 4 },
        { axisX: 4, axisY: 5 },
        { axisX: 4, axisY: 6 },
        { axisX: 4, axisY: 7 },
        { axisX: 5, axisY: 0 },
        { axisX: 5, axisY: 5 },
        { axisX: 5, axisY: 6 },
        { axisX: 5, axisY: 7 },
        { axisX: 6, axisY: 0 },
        { axisX: 6, axisY: 1 },
        { axisX: 6, axisY: 2 },
        { axisX: 6, axisY: 3 },
        { axisX: 6, axisY: 4 },
        { axisX: 6, axisY: 5 },
        { axisX: 6, axisY: 6 },
        { axisX: 6, axisY: 7 },
        { axisX: 7, axisY: 0 },
        { axisX: 7, axisY: 1 },
        { axisX: 7, axisY: 2 },
        { axisX: 7, axisY: 3 },
        { axisX: 7, axisY: 4 },
        { axisX: 7, axisY: 5 },
        { axisX: 7, axisY: 6 },
        // Player one hits on the last step
        { axisX: 0, axisY: 4 },
        { axisX: 1, axisY: 4 },
        { axisX: 2, axisY: 4 },
        { axisX: 2, axisY: 5 },
        { axisX: 2, axisY: 6 },
        { axisX: 5, axisY: 1 },
        { axisX: 5, axisY: 2 },
        { axisX: 5, axisY: 3 },
        { axisX: 5, axisY: 4 },
        { axisX: 7, axisY: 7 }
      ];
    let positionsAttackedByPlayerTwo = [
        // Player one misses on all positions until the last step
        // Add miss positions (x, y) here for each guess
        { axisX: 0, axisY: 0 },
        { axisX: 0, axisY: 1 },
        { axisX: 0, axisY: 2 },
        { axisX: 0, axisY: 3 },
        { axisX: 0, axisY: 4 },
        { axisX: 0, axisY: 5 },
        { axisX: 0, axisY: 6 },
        { axisX: 0, axisY: 7 },
        { axisX: 1, axisY: 0 },
        { axisX: 1, axisY: 2 },
        { axisX: 1, axisY: 3 },
        { axisX: 1, axisY: 4 },
        { axisX: 1, axisY: 5 },
        { axisX: 1, axisY: 6 },
        { axisX: 1, axisY: 7 },
        { axisX: 2, axisY: 0 },
        { axisX: 2, axisY: 1 },
        { axisX: 2, axisY: 2 },
        { axisX: 2, axisY: 3 },
        { axisX: 2, axisY: 4 },
        { axisX: 2, axisY: 5 },
        { axisX: 2, axisY: 6 },
        { axisX: 3, axisY: 0 },
        { axisX: 3, axisY: 1 },
        { axisX: 3, axisY: 2 },
        { axisX: 3, axisY: 6 },
        { axisX: 4, axisY: 0 },
        { axisX: 4, axisY: 1 },
        { axisX: 4, axisY: 2 },
        { axisX: 4, axisY: 3 },
        { axisX: 4, axisY: 4 },
        { axisX: 4, axisY: 5 },
        { axisX: 4, axisY: 6 },
        { axisX: 5, axisY: 0 },
        { axisX: 5, axisY: 1 },
        { axisX: 5, axisY: 2 },
        { axisX: 5, axisY: 3 },
        { axisX: 5, axisY: 4 },
        { axisX: 5, axisY: 5 },
        { axisX: 5, axisY: 6 },
        { axisX: 6, axisY: 0 },
        { axisX: 6, axisY: 1 },
        { axisX: 6, axisY: 2 },
        { axisX: 6, axisY: 5 },
        { axisX: 6, axisY: 6 },
        { axisX: 6, axisY: 7 },
        { axisX: 7, axisY: 0 },
        { axisX: 7, axisY: 1 },
        { axisX: 7, axisY: 2 },
        { axisX: 7, axisY: 3 },
        { axisX: 7, axisY: 4 },
        { axisX: 7, axisY: 5 },
        { axisX: 7, axisY: 6 },
        { axisX: 7, axisY: 7 },
        // Player one hits on the last step
        { axisX: 1, axisY: 1 },
        { axisX: 3, axisY: 3 },
        { axisX: 3, axisY: 4 },
        { axisX: 3, axisY: 5 },
        { axisX: 2, axisY: 7 },
        { axisX: 3, axisY: 7 },
        { axisX: 4, axisY: 7 },
        { axisX: 5, axisY: 7 },
        { axisX: 6, axisY: 3 },
        { axisX: 6, axisY: 4 }
      ];

      const gameSize = 8;
      const gameBoardOne = [];
      const gameBoardTwo = [];
      // Initialize game boards with empty cells (water)
      for (let i = 0; i < gameSize; i++) {
          gameBoardOne.push(Array(gameSize).fill("🌊")); // "🌊" represents water
          gameBoardTwo.push(Array(gameSize).fill("🌊"));
      }

      // Function to update the game board with ship and hit information
      function updateGameBoard(player, x, y, isHit, board) {
          const hitEmoji = "💥"; // Emoji for a hit
          const missEmoji = "💦"; // Emoji for a miss (splash)
      
          const emoji = isHit ? hitEmoji : missEmoji;
      
          if (board == 1) {
              gameBoardOne[y][x] = emoji;
          } else {
              gameBoardTwo[y][x] = emoji;
          }
      }

      // Function to print the game board
    function printGameBoard(boardNum) {
        let board;
        if (boardNum == 1) {
            board = gameBoardOne;
        } else {
            board = gameBoardTwo;
        }
    
        for (let row of board) {
            const spaces = "                 ";
            console.log(spaces + row.join(" "));
        }
    }

    // Merkle tree leaves for player one and player two
    let playerOneLeaves;
    let playerTwoLeaves;

    // Merkle roots for both players
    let playerOneRootHash;
    let playerTwoRootHash;

    before(async () => {
        battleshipInstance = await Battleship.deployed();
        battleshipStorageInstance = await BattleshipStorage.deployed();
    });

    it("Should join a lobby and start a battle", async () => {

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
        await battleshipStorageInstance.setShipPositions(
            playerOneShipLengths,
            playerOneAxisXs,
            playerOneAxisYs,
            playerOneDirections,
            playerOne,
        );

        // Set ship positions for player two
        await battleshipStorageInstance.setShipPositions(
            playerTwoShipLengths,
            playerTwoAxisXs,
            playerTwoAxisYs,
            playerTwoDirections,
            playerTwo,
        );

        // Create Merkle tree leaves for player one and player two
        playerOneLeaves = await battleshipStorageInstance.getMerkleTreeLeaves(playerOne);
        playerTwoLeaves = await battleshipStorageInstance.getMerkleTreeLeaves(playerTwo);
        
        /* console.log("player One leaves:");
        playerOneLeaves.forEach(function(leaf) {
            console.log(leaf);
        }); */
        //console.log("player One leaves:", playerOneLeaves.toString());
        //console.log("-----------------------------------------------");
        //console.log("player Two leaves:", playerTwoLeaves.toString());
        
        await battleshipStorageInstance.calculateMerkleRoot(playerOneLeaves, playerOne);
        await battleshipStorageInstance.calculateMerkleRoot(playerTwoLeaves, playerTwo);

        // Calculate Merkle roots for both players
        playerOneRootHash = await battleshipStorageInstance.
            getMerkleRoot(playerOne);
        playerTwoRootHash = await battleshipStorageInstance.
            getMerkleRoot(playerTwo);
        let gamePhase = GamePhase.Placement;
        
        /*console.log("-----------------------------------------------");
        console.log("-----------------------------------------------");
        console.log("playerOneRootHash:", playerOneRootHash);
        console.log("-----------------------------------------------");
        console.log("playerTwoRootHash:", playerTwoRootHash);
        console.log("-----------------------------------------------");
        console.log("-----------------------------------------------");*/

        // Player One
        let valueInWei = 100000000000000;
        let result;

        result = await battleshipInstance.createLobby(gamePhase, playerOneRootHash, 
            { from: playerOne, value: valueInWei });
            
        assert.equal(result.logs[0].args._playerAddress, playerOne, 
            "Creator account is not valid"); 

        //Check if there is currently a player in the lobby
        result = await battleshipStorageInstance.getLobbyByAddress(playerOne);

        assert.equal(result.isOccupied, true, 
            "Result must indicate that a player is already in the lobby");
            
        // Player Two
        valueInWei = 100000000000000;
        result = await battleshipInstance.joinLobby(playerOne, gamePhase, playerTwoRootHash, 
            { from: playerTwo, value: valueInWei });
        
        battleId = result.logs[0].args._battleId;
       
    });

    it("Should perform an attack and check for winner", async () => {

        for (let attackNumber = 0; attackNumber < 64; attackNumber++) {
            await playerTwoPlay(attackNumber);
            //console.log(board);

            //let delayMilliseconds = 100; // 0.1 seconds
            //await sleep(delayMilliseconds);
            if (attackNumber != 63)
                await playerOnePlay(attackNumber);
            //await sleep(delayMilliseconds);
        }
        console.log("All the attacks has been executed!");
    
        async function playerOnePlay(index){
            let attackingPosition;
            attackingPosition = positionsAttackedByPlayerOne[index]; 
            let proofleaf = await battleshipStorageInstance.generateProof(
                playerTwo, attackingPosition.axisY, attackingPosition.axisX, gameSize);
    
            /*console.log("player One perform the ", index.toString(), "° attack");
            console.log("attackingPosition.axisX:", attackingPosition.axisX);
            console.log("attackingPosition.axisY:", attackingPosition.axisY);
            console.log("-----------------------------------------------");*/
    
            let attackResult = await battleshipInstance.attack(
                battleId, proofleaf, attackingPosition.axisX, 
                attackingPosition.axisY,
                { from: playerOne });
    
            // Watch for the ConfirmShotStatus event
            let confirmShotStatusEvent = attackResult.logs.find(
                log => log.event === "ConfirmShotStatus"
            );
    
            if (confirmShotStatusEvent) {
                
                let isHit = await battleshipStorageInstance.isHit(playerTwo, 
                    attackingPosition.axisX, attackingPosition.axisY);
    
                // Update the game board with the attack result
                updateGameBoard(2, attackingPosition.axisX, 
                    attackingPosition.axisY, isHit, 2);
    
                // Print the updated game board
                /*console.log("Player Two Board:");
                printGameBoard(2);
                console.log("-----------------------------------------------");
                console.log("-----------------------------------------------");*/
            }
        }
        async function playerTwoPlay(index){
            let attackingPosition;
            attackingPosition = positionsAttackedByPlayerTwo[index]; 
            let proofleaf = await battleshipStorageInstance.generateProof(
                playerOne, attackingPosition.axisY, attackingPosition.axisX, gameSize);
    
            /*console.log("player Two perform the ", index.toString(), "° attack");
            console.log("attackingPosition.axisX:", attackingPosition.axisX);
            console.log("attackingPosition.axisY:", attackingPosition.axisY);
            console.log("-----------------------------------------------");*/
    
            let attackResult = await battleshipInstance.attack(
                battleId, proofleaf, attackingPosition.axisX, 
                attackingPosition.axisY,
                { from: playerTwo });
    
            // Watch for the ConfirmShotStatus event
            let confirmShotStatusEvent = attackResult.logs.find(
                log => log.event === "ConfirmShotStatus"
            );
    
            if (confirmShotStatusEvent) {
                
                let isHit = await battleshipStorageInstance.isHit(playerOne, 
                    attackingPosition.axisX, attackingPosition.axisY);
    
                // Update the game board with the attack result
                updateGameBoard(1, attackingPosition.axisX, 
                    attackingPosition.axisY, isHit, 1);
    
                // Print the updated game board
                /*console.log("Player One Board:");
                printGameBoard(1);
                console.log("-----------------------------------------------");
                console.log("-----------------------------------------------");*/
            }
        }
    }); 

    function sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

});