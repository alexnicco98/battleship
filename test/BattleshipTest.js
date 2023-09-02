const Battleship = artifacts.require("Battleship");
const IntBattleshipStruct = artifacts.require("IntBattleshipStruct");
const BattleshipStorage = artifacts.require("BattleshipStorage");
const GamePhase = IntBattleshipStruct.GamePhase;
const ShipDirection = IntBattleshipStruct.ShipDirection;


contract("Battleship", accounts => {
    let battleshipInstance;
    let battleshipStorageInstance;
    let battleId;
    let playerOne = accounts[0];
    let playerTwo = accounts[1];

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
        {axisX: 2, axisY: 2}, {axisX: 3, axisY: 3}];
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
        //merkleTreeInstance = await MerkleTree.deployed();
    });

    // DEBUG
    /*it("should emit StakeValue event with correct stake value", async () => {
        const _gamePhase = GamePhase.Placement; // Replace with your actual game phase
        
        // Perform the emitStackValue transaction
        let transaction = await battleshipInstance.emitStackValueFromGamePhase(_gamePhase);

        // Find the emitted event in the transaction logs
        let stakeEvent = transaction.logs.find(log => log.event === "StakeValue");
        
        // Access the stake value from the event
        let emittedStakeValue = stakeEvent.args.value;

        assert.equal(transaction.logs[0].event, "StakeValue", 
        "Event must indicate that a stake values is emitted");

        // Display the emitted and actual stake values
        console.log("Emitted stake value:", emittedStakeValue.toString());

        await battleshipInstance.emitStackValueFromMsgValue();

        // Find the emitted event in the transaction logs
        let stakeEventTwo = transaction.logs.find(log => log.event === "StakeValue");
        
        // Access the stake value from the event
        let emittedStakeValueTwo = stakeEventTwo.args.value;

        // Display the emitted and actual stake values
        console.log("Emitted stake value 2:", emittedStakeValueTwo.toString());
    });*/

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
        
        console.log("player One leaves:", playerOneLeaves.toString());
        console.log("-----------------------------------------------");
        console.log("player Two leaves:", playerTwoLeaves.toString());

        await battleshipStorageInstance.calculateMerkleRoot(playerOneLeaves, playerOne);
        await battleshipStorageInstance.calculateMerkleRoot(playerTwoLeaves, playerTwo);

        // Calculate Merkle roots for both players
        playerOneRootHash = await battleshipStorageInstance.
            getMerkleRoot(playerOne);
        playerTwoRootHash = await battleshipStorageInstance.
            getMerkleRoot(playerTwo);
        let gamePhase = GamePhase.Placement;
        let lenOne = await battleshipStorageInstance.getMerkleTreeProofLength(playerOne);
        let lenTwo = await battleshipStorageInstance.getMerkleTreeProofLength(playerTwo);
        
        console.log("-----------------------------------------------");
        console.log("-----------------------------------------------");
        console.log("playerOneRootHash:", playerOneRootHash);
        console.log("playerOneRootHash len:", lenOne.toString());
        console.log("-----------------------------------------------");
        console.log("playerTwoRootHash:", playerTwoRootHash);
        console.log("playerTwoRootHash len:", lenTwo.toString());
        console.log("-----------------------------------------------");
        console.log("-----------------------------------------------");

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

        //console.log("Merkle Tree Root value:", retrievedMerkleTreeRoot);

        assert.equal(retrievedMerkleTreeRoot, playerOneRootHash,
            "Retrieved MerkleTreeRoot does not match");
    });

    it("Should perform an attack and check for winner", async () => {
        let attackingPosition = positionsAttackedByPlayerTwo[0]; 
        let currentPositionLeafAttackedByPlayerTwo = await battleshipStorageInstance.
            getMerkleTreeLeaf(playerOne, attackingPosition.axisX, attackingPosition.axisY);
        let proof = await battleshipStorageInstance.getMerkleTreeProof(playerOne);
        let proofleaf = await battleshipStorageInstance.generateProof(
            playerOne, attackingPosition.axisY, attackingPosition.axisX);
        // Get the current state of the battle
        let initialBattleState = await battleshipStorageInstance.getBattle(battleId);

        console.log("playerTwo perform the 1° attack");
        console.log("battleId:", battleId.toString());
        console.log("proofleaf return from getMerkleTreeProof:", proof);
        console.log("proofleaf generate from generateProof:", proofleaf);
        console.log("currentPositionLeafAttackedByPlayerTwo:", 
            currentPositionLeafAttackedByPlayerTwo);
        console.log("attackingPosition.axisX:", attackingPosition.axisX);
        console.log("attackingPosition.axisY:", attackingPosition.axisY);
        console.log("playerTwo:", playerTwo);
        console.log("-----------------------------------------------");
        console.log("-----------------------------------------------");

        let verify = await battleshipStorageInstance.verifyProof(
            proofleaf, playerOne, attackingPosition.axisY, attackingPosition.axisX);

        console.log("Verifiy bool:", verify);

        // playerTwo perform the 1° attack
        let attackResult = await battleshipInstance.attack(
            battleId, proofleaf, attackingPosition.axisX, attackingPosition.axisY,
            { from: playerTwo });
    
        // Get the updated state of the battle
        let updatedBattleState = await battleshipStorageInstance.getBattle(battleId);
        len = await battleshipStorageInstance.getPositionsAttackedLength(battleId, 
            playerTwo);
        console.log("len after: ", len.toString());

        // ------------------------------------------------------------------
        // playerOne perform the 1° attack
        attackingPosition = positionsAttackedByPlayerOne[0];
        let currentPositionLeafAttackedByPlayerOne = await battleshipStorageInstance.
            getMerkleTreeLeaf(playerTwo, attackingPosition.axisX, attackingPosition.axisY);
        proof = await battleshipStorageInstance.getMerkleTreeProof(playerTwo);
        proofleaf = await battleshipStorageInstance.generateProof(
            playerTwo, attackingPosition.axisY, attackingPosition.axisX);
        proof = await battleshipStorageInstance.getMerkleTreeProof(playerOne);
        
        console.log("playerOne perform the 1° attack");
        console.log("currentPositionLeafAttackedByPlayerOne:", 
            currentPositionLeafAttackedByPlayerOne);
        console.log("attackingPosition.axisX:", attackingPosition.axisX);
        console.log("attackingPosition.axisY:", attackingPosition.axisY);
        console.log("-----------------------------------------------");
        console.log("-----------------------------------------------");
        console.log("proofleaf return from getMerkleTreeProof:", proof);
        console.log("proofleaf generate from generateProof:", proofleaf);
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
        
        // ------------------------------------------------------------------
        // playerTwo perform the 2° attack
        attackingPosition = positionsAttackedByPlayerTwo[1];
        currentPositionLeafAttackedByPlayerTwo = await battleshipStorageInstance.
            getMerkleTreeLeaf(playerOne, attackingPosition.axisX, attackingPosition.axisY);
        proof = await battleshipStorageInstance.getMerkleTreeProof(playerOne);
        proofleaf = await battleshipStorageInstance.generateProof(
            playerOne, attackingPosition.axisY, attackingPosition.axisX);
        
        console.log("playerTwo perform the 2° attack");
        console.log("currentPositionLeafAttackedByPlayerTwo:", 
            currentPositionLeafAttackedByPlayerTwo);
        console.log("attackingPosition.axisX:", attackingPosition.axisX);
        console.log("attackingPosition.axisY:", attackingPosition.axisY);
        console.log("-----------------------------------------------");
        console.log("-----------------------------------------------");

        len = await battleshipStorageInstance.getPositionsAttackedLength(battleId, 
            playerTwo);
        console.log("len before: ", len.toString());

        attackResult = await battleshipInstance.attack(
            battleId, proofleaf, attackingPosition.axisX, attackingPosition.axisY,
            { from: playerTwo });
        
        len = await battleshipStorageInstance.getPositionsAttackedLength(battleId, 
                playerTwo);
        console.log("len after: ", len.toString());

        // ------------------------------------------------------------------
        // playerOne perform the 2° attack
        attackingPosition = positionsAttackedByPlayerOne[1];
        currentPositionLeafAttackedByPlayerOne = await battleshipStorageInstance.
            getMerkleTreeLeaf(playerTwo, attackingPosition.axisX, attackingPosition.axisY);
        proofleaf = await battleshipStorageInstance.generateProof(
            playerTwo, attackingPosition.axisY, attackingPosition.axisX);
        
        console.log("playerOne perform the 2° attack");
        console.log("currentPositionLeafAttackedByPlayerOne:", 
            currentPositionLeafAttackedByPlayerOne);
        console.log("attackingPosition.axisX:", attackingPosition.axisX);
        console.log("attackingPosition.axisY:", attackingPosition.axisY);
        console.log("-----------------------------------------------");
        console.log("-----------------------------------------------");

        attackResult = await battleshipInstance.attack(
            battleId, proofleaf, attackingPosition.axisX, attackingPosition.axisY, 
            { from: playerOne });

        // ------------------------------------------------------------------
        // playerTwo perform the 3° attack
        attackingPosition = positionsAttackedByPlayerTwo[2];
        currentPositionLeafAttackedByPlayerTwo = await battleshipStorageInstance.
            getMerkleTreeLeaf(playerOne, attackingPosition.axisX, attackingPosition.axisY);
        proofleaf = await battleshipStorageInstance.generateProof(
            playerOne, attackingPosition.axisY, attackingPosition.axisX);
        
        attackResult = await battleshipInstance.attack(
            battleId, proofleaf, attackingPosition.axisX, attackingPosition.axisY, 
            { from: playerTwo });

        // ------------------------------------------------------------------
        // playerOne perform the 3° attack
        attackingPosition = positionsAttackedByPlayerOne[2];
        currentPositionLeafAttackedByPlayerOne = await battleshipStorageInstance.
            getMerkleTreeLeaf(playerTwo, attackingPosition.axisX, attackingPosition.axisY);
        proofleaf = await battleshipStorageInstance.generateProof(
            playerTwo, attackingPosition.axisY, attackingPosition.axisX);
        
        attackResult = await battleshipInstance.attack(
            battleId, proofleaf, attackingPosition.axisX, attackingPosition.axisY,
            { from: playerOne });

        // ------------------------------------------------------------------
        // playerTwo perform the 4° attack
        attackingPosition = positionsAttackedByPlayerTwo[3];
        currentPositionLeafAttackedByPlayerTwo = await battleshipStorageInstance.
            getMerkleTreeLeaf(playerOne, attackingPosition.axisX, attackingPosition.axisY);
        proofleaf = await battleshipStorageInstance.generateProof(
            playerOne, attackingPosition.axisY, attackingPosition.axisX);

        attackResult = await battleshipInstance.attack(
            battleId, proofleaf, attackingPosition.axisX, attackingPosition.axisY, 
            { from: playerTwo });

        // ------------------------------------------------------------------
        // playerOne perform the 4° attack
        /*attackingPosition = positionsAttackedByPlayerOne[3];
        currentPositionLeafAttackedByPlayerOne = await battleshipStorageInstance.
            getMerkleTreeLeaf(playerTwo, attackingPosition.axisX, attackingPosition.axisY);
        proofleaf = await battleshipStorageInstance.generateProof(
            playerTwo, attackingPosition.axisY, attackingPosition.axisX);
        
        attackResult = await battleshipInstance.attack(
            battleId, proofleaf, attackingPosition.axisX, attackingPosition.axisY, 
            { from: playerOne });*/
        
        console.log("event: ", attackResult.logs[2].event);

        assert.equal(attackResult.logs[2].event, "WinnerDetected", 
            "Event containing more details about the winner");
    

        updatedBattleState = await battleshipStorageInstance.getBattle(battleId);
    
        // Check if there is a winner
        if (updatedBattleState.isCompleted) {
            console.log("Winner address", updatedBattleState.winner);
        }
    }); 

});