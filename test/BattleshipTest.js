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
    const gameSize = 4;

    console.log("player One adrress: ", playerOne);
    console.log("player Two adrress: ", playerTwo);

    // Positions for player one and two
    let playerOnePositions = [
        { shipLength: 1, axisX: 1, axisY: 1, direction: ShipDirection.Horizontal },
        { shipLength: 2, axisX: 2, axisY: 2, direction: ShipDirection.Vertical }
    ];
    let playerTwoPositions = [
        { shipLength: 1, axisX: 0, axisY: 1, direction: ShipDirection.Horizontal },
        { shipLength: 2, axisX: 3, axisY: 0, direction: ShipDirection.Vertical }
    ];

    // Positions attacked by player one and two
    let positionsAttackedByPlayerOne = [{axisX: 0, axisY: 1}, {axisX: 0, axisY: 3},
        {axisX: 1, axisY: 2}, {axisX: 3, axisY: 3}];
    let positionsAttackedByPlayerTwo = [{axisX: 0, axisY: 0}, {axisX: 2, axisY: 2}, 
        {axisX: 2, axisY: 3}, {axisX: 1, axisY: 1}];

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
    
        // Check that the BattleStarted Event is emitted
        assert.equal(result.logs[0].event, "BattleStarted", 
            "Event must indicate that a battle has started"); 

        //Check if there is currently a player in the lobby
        const lobby = await battleshipStorageInstance.getLobbyByAddress(playerOne);
        
        // Check if lobby is occupied
        assert.equal(lobby.isOccupied, true, "Lobby should be occupied");
    
        // Check if both players are included in the event log for the battle
        assert.equal(lobby.playerOneRootHash, 
            playerOneRootHash, "Player one is included");

        assert.equal(lobby.playerTwoRootHash, 
            playerTwoRootHash, "Player two is included");
       
    });

    it("Should store and retrieve the Merkle tree root", async () => {
        
        // Retrieve the Merkle tree root, return a bytes32 instead of a string
        const retrievedMerkleTreeRoot = await battleshipStorageInstance.
            getMerkleTreeRootByBattleIdAndPlayer(battleId, playerOne);

        assert.equal(retrievedMerkleTreeRoot, playerOneRootHash,
            "Retrieved MerkleTreeRoot does not match");
    });

    it("Should perform an attack and check for winner", async () => {
        const gameSize = 4;
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

        function areAllPositionsUnique(positions) {
            let seen = {};
        
            for (let i = 0; i < positions.length; i++) {
            let position = positions[i];
            // Create a unique key by concatenating axisX and axisY as a string
            let positionKey = position.axisX.toString() + "-" + position.axisY.toString();
        
            if (seen[positionKey]) {
                // This position combination has been seen before, not all positions are unique
                return false;
            }
            
            seen[positionKey] = true;
            }
        
            // All position combinations are unique
            return true;
        }
        
        let playerOneIsUnique = areAllPositionsUnique(positionsAttackedByPlayerOne);
        let playerTwoIsUnique = areAllPositionsUnique(positionsAttackedByPlayerTwo);

        if (playerOneIsUnique) {
            console.log("Player One: All positions are unique");
        } else {
            console.log("Player One: Some positions are not unique, indicating possible cheating.");
        }
        if (playerTwoIsUnique) {
            console.log("Player Two: All positions are unique");
        } else {
            console.log("Player Two: Some positions are not unique, indicating possible cheating.");
        }

        let attackingPosition = positionsAttackedByPlayerTwo[0]; 
        let proofleaf = await battleshipStorageInstance.generateProof(
            playerOne, attackingPosition.axisY, attackingPosition.axisX, 
            gameSize);
        // Get the current state of the battle
        let initialBattleState = await battleshipStorageInstance.getBattle(battleId);

        console.log("playerTwo perform the 1° attack");
        console.log("attackingPosition.axisX:", attackingPosition.axisX);
        console.log("attackingPosition.axisY:", attackingPosition.axisY);
        console.log("-----------------------------------------------");

        // playerTwo perform the 1° attack
        let attackResult = await battleshipInstance.attack(
            battleId, proofleaf, attackingPosition.axisX, attackingPosition.axisY,
            { from: playerTwo });
    
        // Get the updated state of the battle
        let updatedBattleState = await battleshipStorageInstance.getBattle(battleId);

        // Watch for the ConfirmShotStatus event
        let confirmShotStatusEvent = attackResult.logs.find(
            log => log.event === "ConfirmShotStatus"
        );

        if (confirmShotStatusEvent) {
            
            const isHit = await battleshipStorageInstance.isHit(playerOne, attackingPosition.axisX, attackingPosition.axisY);

            // Update the game board with the attack result
            updateGameBoard(1, attackingPosition.axisX, attackingPosition.axisY, isHit, 1);

            // Print the updated game board
            console.log("Player One Board:");
            printGameBoard(1);
            console.log("-----------------------------------------------");
            console.log("-----------------------------------------------");
        }

        // ------------------------------------------------------------------
        // playerOne perform the 1° attack
        attackingPosition = positionsAttackedByPlayerOne[0];
        proofleaf = await battleshipStorageInstance.generateProof(
            playerTwo, attackingPosition.axisY, attackingPosition.axisX,
            gameSize);
        
        console.log("playerOne perform the 1° attack");
        console.log("attackingPosition.axisX:", attackingPosition.axisX);
        console.log("attackingPosition.axisY:", attackingPosition.axisY);
        console.log("-----------------------------------------------");
        console.log("-----------------------------------------------");

        // Get the current state of the battle
        initialBattleState = await battleshipStorageInstance.
            getLastPlayTimeByBattleId(battleId);

        // Perform the attack
        attackResult = await battleshipInstance.attack(
            battleId, proofleaf, attackingPosition.axisX, attackingPosition.axisY, 
            { from: playerOne });

        // Check if the attack was successful
        assert.equal(attackResult.receipt.status, true, "Attack was not successful");

        // Get the updated battle state after the attack
        updatedBattleState = await battleshipStorageInstance.
            getLastPlayTimeByBattleId(battleId);

        // Compare battle state before and after the attack
        assert.notEqual(updatedBattleState, initialBattleState, 
            "Last play time was not updated");
        
        // Watch for the ConfirmShotStatus event
        confirmShotStatusEvent = attackResult.logs.find(
            log => log.event === "ConfirmShotStatus"
        );

        if (confirmShotStatusEvent) {
            
            const isHit = await battleshipStorageInstance.isHit(playerTwo, attackingPosition.axisX, attackingPosition.axisY);

            // Update the game board with the attack result
            updateGameBoard(2, attackingPosition.axisX, attackingPosition.axisY, isHit, 2);

            // Print the updated game board
            console.log("Player Two Board:");
            printGameBoard(2);
            console.log("-----------------------------------------------");
            console.log("-----------------------------------------------");
        }
        
        // ------------------------------------------------------------------
        // playerTwo perform the 2° attack
        attackingPosition = positionsAttackedByPlayerTwo[1];
        proofleaf = await battleshipStorageInstance.generateProof(
            playerOne, attackingPosition.axisY, attackingPosition.axisX, 
            gameSize);
        
        console.log("playerTwo perform the 2° attack");
        console.log("attackingPosition.axisX:", attackingPosition.axisX);
        console.log("attackingPosition.axisY:", attackingPosition.axisY);
        console.log("-----------------------------------------------");

        attackResult = await battleshipInstance.attack(
            battleId, proofleaf, attackingPosition.axisX, attackingPosition.axisY,
            { from: playerTwo });

        // Watch for the ConfirmShotStatus event
        confirmShotStatusEvent = attackResult.logs.find(
            log => log.event === "ConfirmShotStatus"
        );

        if (confirmShotStatusEvent) {
            
            const isHit = await battleshipStorageInstance.isHit(playerOne, attackingPosition.axisX, attackingPosition.axisY);

            // Update the game board with the attack result
            updateGameBoard(1, attackingPosition.axisX, attackingPosition.axisY, isHit, 1);

            // Print the updated game board
            console.log("Player One Board:");
            printGameBoard(1);
            console.log("-----------------------------------------------");
            console.log("-----------------------------------------------");
        }

        // ------------------------------------------------------------------
        // playerOne perform the 2° attack
        attackingPosition = positionsAttackedByPlayerOne[1];
        proofleaf = await battleshipStorageInstance.generateProof(
            playerTwo, attackingPosition.axisY, attackingPosition.axisX, 
            gameSize);
        
        console.log("playerOne perform the 2° attack");
        console.log("attackingPosition.axisX:", attackingPosition.axisX);
        console.log("attackingPosition.axisY:", attackingPosition.axisY);
        console.log("-----------------------------------------------");

        attackResult = await battleshipInstance.attack(
            battleId, proofleaf, attackingPosition.axisX, attackingPosition.axisY, 
            { from: playerOne });

        // Watch for the ConfirmShotStatus event
        confirmShotStatusEvent = attackResult.logs.find(
            log => log.event === "ConfirmShotStatus"
        );

        if (confirmShotStatusEvent) {
            
            const isHit = await battleshipStorageInstance.isHit(playerTwo, attackingPosition.axisX, attackingPosition.axisY);

            // Update the game board with the attack result
            updateGameBoard(2, attackingPosition.axisX, attackingPosition.axisY, isHit, 2);

            // Print the updated game board
            console.log("Player Two Board:");
            printGameBoard(2);
            console.log("-----------------------------------------------");
            console.log("-----------------------------------------------");
        }

        // ------------------------------------------------------------------
        // playerTwo perform the 3° attack
        attackingPosition = positionsAttackedByPlayerTwo[2];
        proofleaf = await battleshipStorageInstance.generateProof(
            playerOne, attackingPosition.axisY, attackingPosition.axisX,
            gameSize);

        console.log("playerTwo perform the 3° attack");
        console.log("attackingPosition.axisX:", attackingPosition.axisX);
        console.log("attackingPosition.axisY:", attackingPosition.axisY);
        console.log("-----------------------------------------------");
        
        attackResult = await battleshipInstance.attack(
            battleId, proofleaf, attackingPosition.axisX, attackingPosition.axisY, 
            { from: playerTwo });

        // Watch for the ConfirmShotStatus event
        confirmShotStatusEvent = attackResult.logs.find(
            log => log.event === "ConfirmShotStatus"
        );

        if (confirmShotStatusEvent) {
            
            const isHit = await battleshipStorageInstance.isHit(playerOne, attackingPosition.axisX, attackingPosition.axisY);

            // Update the game board with the attack result
            updateGameBoard(1, attackingPosition.axisX, attackingPosition.axisY, isHit, 1);

            // Print the updated game board
            console.log("Player One Board:");
            printGameBoard(1);
            console.log("-----------------------------------------------");
            console.log("-----------------------------------------------");
        }

        // ------------------------------------------------------------------
        // playerOne perform the 3° attack
        attackingPosition = positionsAttackedByPlayerOne[2];
        proofleaf = await battleshipStorageInstance.generateProof(
            playerTwo, attackingPosition.axisY, attackingPosition.axisX,
            gameSize);

        console.log("playerOne perform the 3° attack");
        console.log("attackingPosition.axisX:", attackingPosition.axisX);
        console.log("attackingPosition.axisY:", attackingPosition.axisY);
        console.log("-----------------------------------------------");
        
        attackResult = await battleshipInstance.attack(
            battleId, proofleaf, attackingPosition.axisX, attackingPosition.axisY,
            { from: playerOne });
        
        // Watch for the ConfirmShotStatus event
        confirmShotStatusEvent = attackResult.logs.find(
            log => log.event === "ConfirmShotStatus"
        );

        if (confirmShotStatusEvent) {
            
            const isHit = await battleshipStorageInstance.isHit(playerTwo, attackingPosition.axisX, attackingPosition.axisY);

            // Update the game board with the attack result
            updateGameBoard(2, attackingPosition.axisX, attackingPosition.axisY, isHit, 2);

            // Print the updated game board
            console.log("Player Two Board:");
            printGameBoard(2);
            console.log("-----------------------------------------------");
            console.log("-----------------------------------------------");
        }

        // ------------------------------------------------------------------
        // playerTwo perform the 4° attack
        attackingPosition = positionsAttackedByPlayerTwo[3];
        proofleaf = await battleshipStorageInstance.generateProof(
            playerOne, attackingPosition.axisY, attackingPosition.axisX,
            gameSize);

        console.log("playerTwo perform the 4° attack");
        console.log("attackingPosition.axisX:", attackingPosition.axisX);
        console.log("attackingPosition.axisY:", attackingPosition.axisY);
        console.log("-----------------------------------------------");

        attackResult = await battleshipInstance.attack(
            battleId, proofleaf, attackingPosition.axisX, attackingPosition.axisY, 
            { from: playerTwo });

        // Watch for the ConfirmShotStatus event
        confirmShotStatusEvent = attackResult.logs.find(
            log => log.event === "ConfirmShotStatus"
        );

        if (confirmShotStatusEvent) {
            
            const isHit = await battleshipStorageInstance.isHit(playerOne, attackingPosition.axisX, attackingPosition.axisY);

            // Update the game board with the attack result
            updateGameBoard(1, attackingPosition.axisX, attackingPosition.axisY, isHit, 1);

            // Print the updated game board
            console.log("Player One Board:");
            printGameBoard(1);
            console.log("-----------------------------------------------");
            console.log("-----------------------------------------------");
        }
        
        console.log("event: ", attackResult.logs[2].event);

        assert.equal(attackResult.logs[3].event, "WinnerDetected", 
            "Event containing more details about the winner");

        updatedBattleState = await battleshipStorageInstance.getBattle(battleId);
    
        // Check if there is a winner
        if (updatedBattleState.isCompleted) {
            console.log("Winner address", updatedBattleState.winner);
            if (updatedBattleState.winner === playerOne)
                console.log("Player One wins!");
            else
                console.log("Player Two wins!");
        }
    }); 

});