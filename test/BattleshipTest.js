const Battleship = artifacts.require("Battleship");
const IntBattleshipStruct = artifacts.require("IntBattleshipStruct");
const BattleshipStorage = artifacts.require("BattleshipStorage");
const GamePhase = IntBattleshipStruct.GamePhase;
const ShipDirection = IntBattleshipStruct.ShipDirection;


contract("Battleship", accounts => {
    let battleshipInstance;
    let battleshipStorageInstance;
    let battleId;
    let encryptedMerkleTree = "encryptedmerkletree";
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
    let positionsAttackedByPlayerOne = [{axisX: 0, axisY: 1}, {axisX: 0, axisY: 3}];
    let positionsAttackedByPlayerTwo = [{axisX: 0, axisY: 0}, {axisX: 2, axisY: 2}];

    let previousPositionProofSubmittedByPlayerOne = [];
    let previousPositionProofSubmittedByPlayerTwo = [];

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
        playerOneLeaves = await battleshipStorageInstance.createMerkleTreeLeaves(playerOneShipLengths, playerOneAxisXs, playerOneAxisYs, playerOneDirections);
        playerTwoLeaves = await battleshipStorageInstance.createMerkleTreeLeaves(playerTwoShipLengths, playerTwoAxisXs, playerTwoAxisYs, playerTwoDirections);

        // Calculate Merkle roots for both players
        playerOneRootHash = await battleshipStorageInstance.calculateMerkleRoot(playerOneLeaves);
        playerTwoRootHash = await battleshipStorageInstance.calculateMerkleRoot(playerTwoLeaves);
        let gamePhase = GamePhase.Placement;

        console.log("playerOneLeaves:", playerOneLeaves.toString());
        //console.log("playerOneRootHash:", playerOneRootHash.toString());

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
        
        battleId = result;

        console.log("playerOneRootHash:", playerOneRootHash.toString());
        console.log("playerTwoRootHash:", playerTwoRootHash.toString());
    
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

    /*it("Should store and retrieve encrypted MerkleTree", async () => {
    
        // Store encrypted MerkleTree
        await battleshipStorageInstance.setEncryptedMerkleTreeByBattleIdAndPlayer(
            battleId, playerOne, playerOneLeaves);
            
        // Retrieve encrypted MerkleTree, return a bytes32 instead of a string
        const retrievedEncryptedMerkleTree = await battleshipInstance.getPlayersEncryptedPositions(
            battleId, { from: playerOne });

        console.log("Encrypted Merkle Tree value:", retrievedEncryptedMerkleTree.toString());

        assert.equal(retrievedEncryptedMerkleTree, encryptedMerkleTree,
            "Retrieved encrypted MerkleTree does not match");
        
    //try {} catch (error) {console.error("Transaction reverted with reason:", error.reason);}
    });*/

    it("should launch an attack", async () => {
        // Write your test logic here
    });

    // Add more test cases as needed
});

/*it("should join a lobby and start a battle", async () => {
        let playerOneRootHash = "0xc509DBED5b5da5AB96b0b3d9159cE3aaa9BCB57c";
        let playerTwoRootHash = "0x88e13dA7445bE1E90b5d0FA141bDc1D750c8182F";
        let _gamePhase = GamePhase.Placement;

        return Battleship.deployed()
        .then(battleshipInstance => {
            battleship = instance;
            
            let valueInWei = msg.value;
            return battleshipInstance.joinLobby(_gamePhase, playerOneRootHash, encryptedMerkleTree, { from: playerOne, value: valueInWei });
        })
        .then(result => {
            assert.equal(result.logs[0].event, "PlayerJoinedLobby", "Event must indicate that a player has joined the lobby");
            assert.equal(result.logs[0].args._player, playerOne, "Creator account is not valid");
            assert.equal(result.logs[0].args._gamePhase.valueOf(), gamePhase, "Game mode is not valid");

            let valueInWei = msg.value;
            return battleshipInstance.joinLobby(gamePhase, playerTwoRootHash, encryptedMerkleTree, { from: playerTwo, value: valueInWei });
        })
        .then(result => {
            battleId = result.logs[0].args._battleId;
            let players = result.logs[0].args._players;
            let gamePhase = result.logs[0].args._gamePhase.valueOf();

            // Check that the BattleStarted Event is emitted
            assert.equal(result.logs[0].event, "BattleStarted", "Event must indicate that a battle has started");

            // Check if both players are included in the event log for the battle
            assert.equal(players.includes(playerOne) && players.includes(playerTwo), true, "Battle must include both players");

            // Check that the game mode is equal to the game mode entered by the initial player and also equal to the game mode entered by the current player
            assert.equal(gamePhase == gamePhase, true, "Game mode must be equal to the starting game mode for the Match/Lobby");
        });
    });*/

/*contract("Battleship", accounts => {

    let battleship;
    let battleId;
    let encryptedMerkleTree = "encryptedmerkletree";
    let playerOne = accounts[0];
    let playerTwo = accounts[1];

    // Positions for player one and two
    let playerOnePositions = [1,2,3,4,5,6,7,8,11,12,13,14,15,16,17,18,19];
    let playerTwoPositions = [1,11,2,12,22,3,13,23,4,14,24,34,5,15,25,35,45];

    // Positions attacked by player one and two
    let positionsAttackedByPlayerOne = [1,11,2,12,22,3,13,23,4,14,24,34,5,15,25,35,45];
    let positionsAttackedByPlayerTwo = [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17];

    // Previous position leafs submitted by player one and two
    let previousPositionsLeafsSubmittedByPlayerOne = ["", "1100", "1100", "2100", "2100","2100", "3100", "3100", "3100", "0011", "0011", "4100", "4100", "4100", "4100", "5100", "5100", "5100"];
    let previousLeafPositionsSubmittedByPlayerTwo = ["", "1200", "1200", "2200", "2200", "2200", "3200", "3200", "3200", "4200", "4200", "4200", "4200", "5200", "5200", "5200", "5200", "5200"];

    let previousPositionProofSubmittedByPlayerOne = [];
    let previousPositionProofSubmittedByPlayerTwo = [];

    it("Should join a lobby and start a battle", () => {
        let playerOneRootHash = "0xc509DBED5b5da5AB96b0b3d9159cE3aaa9BCB57c";
        let playerTwoRootHash = "0x88e13dA7445bE1E90b5d0FA141bDc1D750c8182F";
        let gamePhase = GamePhase.Placement;

        return Battleship.deployed()
        .then(instance => {
            battleship = instance;
            let valueInWei = 1000000000000000;
            return instance.joinLobby(gamePhase, playerOneRootHash, encryptedMerkleTree, { from: playerOne, value: valueInWei });
        })
        .then(result => {
            assert.equal(result.logs[0].event, "PlayerJoinedLobby", "Event must indicate that a player has joined the lobby");
            assert.equal(result.logs[0].args._player, playerOne, "Creator account is not valid");
            assert.equal(result.logs[0].args._gamePhase.valueOf(), gamePhase, "Game mode is not valid");

            let valueInWei = 1000000000000000;
            return battleship.joinLobby(gamePhase, playerTwoRootHash, encryptedMerkleTree, { from: playerTwo, value: valueInWei });
        })
        .then(result => {
            battleId = result.logs[0].args._battleId;
            let players = result.logs[0].args._players;
            let gamePhase = result.logs[0].args._gamePhase.valueOf();

            // Check that the BattleStarted Event is emitted
            assert.equal(result.logs[0].event, "BattleStarted", "Event must indicate that a battle has started");

            // Check if both players are included in the event log for the battle
            assert.equal(players.includes(playerOne) && players.includes(playerTwo), true, "Battle must include both players");

            // Check that the game mode is equal to the game mode entered by the initial player and also equal to the game mode entered by the current player
            assert.equal(gamePhase == gamePhase, true, "Game mode must be equal to the starting game mode for the Match/Lobby");
        });
    });

    it("Should get player's encrypted positions", () => {
        return battleship.getPlayersEncryptedPositions(battleId)
        .then(result => {
            // Ensure that the merkle tree is correct
            assert.equal(result.valueOf(), encryptedMerkleTree, "Encrypted Merkle tree value is wrong");
        });
    });

    it("Should launch an attack from the first player", () => {
        let previousPositionLeaf = 0;
        let previousPositionProof = 0x00;
        let attackingPositionX = 1;
        let attackingPositionY = 1;

        return battleship.attack(battleId, previousPositionLeaf, previousPositionProof, 1, 1, { from: playerTwo })
        .then(result => {
            let confirmShotStatusEvent = result.logs[0];
            let attackLaunchedEvent = result.logs[1];

            assert.equal(result.receipt.status, true, "Transaction must have a successful receipt status");

            // Confirm Shot Status Event
            assert.equal(confirmShotStatusEvent.event, "ConfirmShotStatus", "First log event must be of type Confirm Shot logs");
            assert.equal(confirmShotStatusEvent.args._battleId.toNumber(), battleId.toNumber(), "Battle Id is not valid");
            assert.equal(confirmShotStatusEvent.args._confirmingPlayer, playerTwo, "Confirming player is not valid");
            assert.equal(confirmShotStatusEvent.args._opponent, playerOne, "Opponent Player is not valid");
            assert.equal(confirmShotStatusEvent.args._position.toNumber(), 0, "Previous Attacked Position is not valid");
            assert.equal(confirmShotStatusEvent.args._shipDetected.state, ShipState.Intact, "Previous Ship state must be of type Intact because this is the first attack to be launched");

            // Attack Launched Event
            assert.equal(attackLaunchedEvent.args._battleId.toNumber(), battleId.toNumber(), "Battle Id is not valid");
            assert.equal(attackLaunchedEvent.args._launchingPlayer, playerTwo, "Attacking player is not valid");
            assert.equal(attackLaunchedEvent.args._opponent, playerOne, "Opponent player is not valid");
            assert.equal(attackLaunchedEvent.args._position.toNumber(), attackingPosition, "Attacking position is not valid");
        });
    });

    it("Should launch an attack from the second player", () => {
        // Implement this test case
    });
});*/
