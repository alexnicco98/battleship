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

    before(async () => {
        battleshipInstance = await Battleship.deployed();
        battleshipStorageInstance = await BattleshipStorage.deployed();
    });

    // check that the requirment inside "Hit and sunk: implementation on the blockchain" are met
    it("Should join a lobby and check if the ship positions are valid", async () => {
        // Positions for player one and two
        let playerOnePositions = [
            { shipLength: 1, axisX: 1, axisY: 1, direction: ShipDirection.Horizontal },
            { shipLength: 2, axisX: 3, axisY: 3, direction: ShipDirection.Vertical }
        ];
        let playerTwoPositions = [
            { shipLength: 1, axisX: 0, axisY: 1, direction: ShipDirection.Horizontal },
            { shipLength: 2, axisX: 3, axisY: 0, direction: ShipDirection.Vertical }
        ];

        // Merkle tree leaves for player one and player two
        let playerOneLeaves;
        let playerTwoLeaves;

        // Merkle roots for both players
        let playerOneRootHash;
        let playerTwoRootHash;
        // Convert the player positions objects to individual arguments
        let playerOneShipLengths = playerOnePositions.map(ship => ship.shipLength);
        let playerOneAxisXs = playerOnePositions.map(ship => ship.axisX);
        let playerOneAxisYs = playerOnePositions.map(ship => ship.axisY);
        let playerOneDirections = playerOnePositions.map(ship => ship.direction);

        const playerTwoShipLengths = playerTwoPositions.map(ship => ship.shipLength);
        const playerTwoAxisXs = playerTwoPositions.map(ship => ship.axisX);
        const playerTwoAxisYs = playerTwoPositions.map(ship => ship.axisY);
        const playerTwoDirections = playerTwoPositions.map(ship => ship.direction);

        // Set ship positions for player one
        try {
            await battleshipStorageInstance.setShipPositions(
                playerOneShipLengths,
                playerOneAxisXs,
                playerOneAxisYs,
                playerOneDirections,
                playerOne,
            );

        } catch (error) {
            // handle the requirment #2
            if (error.message.includes("Ship would go out of bounds vertically")) {
                console.log("Caught expected error: Ship would go out of bounds vertically");
                console.log("-----------------------------------------------");
                console.log("-----------------------------------------------");
            } else {
                throw error;
            }
        }

        // correct the positions
        playerOnePositions = [
            { shipLength: 1, axisX: 1, axisY: 1, direction: ShipDirection.Horizontal },
            { shipLength: 2, axisX: 2, axisY: 2, direction: ShipDirection.Vertical }
        ];

        playerOneShipLengths = playerOnePositions.map(ship => ship.shipLength);
        playerOneAxisXs = playerOnePositions.map(ship => ship.axisX);
        playerOneAxisYs = playerOnePositions.map(ship => ship.axisY);
        playerOneDirections = playerOnePositions.map(ship => ship.direction);

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

        // try to change the ship positions
        playerTwoPositions = [
            { shipLength: 1, axisX: 0, axisY: 2, direction: ShipDirection.Horizontal },
            { shipLength: 2, axisX: 1, axisY: 2, direction: ShipDirection.Horizontal }
        ];

        const newPlayerTwoShipLengths = playerTwoPositions.map(ship => ship.shipLength);
        const newPlayerTwoAxisXs = playerTwoPositions.map(ship => ship.axisX);
        const newPlayerTwoAxisYs = playerTwoPositions.map(ship => ship.axisY);
        const newPlayerTwoDirections = playerTwoPositions.map(ship => ship.direction);

        // Set ship positions for player two
        const cheating = await battleshipStorageInstance.setShipPositions(
            newPlayerTwoShipLengths,
            newPlayerTwoAxisXs,
            newPlayerTwoAxisYs,
            newPlayerTwoDirections,
            playerTwo,
        );
        
        // handle the requirment #1
        // Check if the cheating transaction has events
        if (cheating.receipt.logs.length > 0) {
            // Detect the PlayerCheating event
            assert.equal(cheating.receipt.logs[0].event, 
                "PlayerCheating", "Expected PlayerCheating event for playerTwo");
        } else {
            // Handle the case where there are no logs
            assert.fail("Expected PlayerCheating event, but no events were emitted");
        }

        // Create Merkle tree leaves for player one and player two
        playerOneLeaves = await battleshipStorageInstance.getMerkleTreeLeaves(playerOne);
        playerTwoLeaves = await battleshipStorageInstance.getMerkleTreeLeaves(playerTwo);

        await battleshipStorageInstance.calculateMerkleRoot(playerOneLeaves, playerOne);
        await battleshipStorageInstance.calculateMerkleRoot(playerTwoLeaves, playerTwo);

        // Calculate Merkle roots for both players
        playerOneRootHash = await battleshipStorageInstance.
            getMerkleRoot(playerOne);
        playerTwoRootHash = await battleshipStorageInstance.
            getMerkleRoot(playerTwo);
        let gamePhase = GamePhase.Placement;

        // Player One
        let valueInWei = 100000000000000;
        let result;

        result = await battleshipInstance.createLobby(gamePhase, playerOneRootHash, 
            { from: playerOne, value: valueInWei });
            
        // Player Two
        valueInWei = 100000000000000;
        result = await battleshipInstance.joinLobby(playerOne, gamePhase, playerTwoRootHash, 
            { from: playerTwo, value: valueInWei });
        
        battleId = result.logs[0].args._battleId;
       
    });

    it("Should perform an attack and check for winner", async () => {
        // Positions attacked by player one and two
        let positionsAttackedByPlayerOne = [{axisX: 0, axisY: 1}, {axisX: 0, axisY: 3},
            {axisX: 2, axisY: 2}, {axisX: 3, axisY: 3}];
        let positionsAttackedByPlayerTwo = [{axisX: 0, axisY: 0}, {axisX: 2, axisY: 2}, 
            {axisX: 2, axisY: 3}, {axisX: 1, axisY: 1}];

        let attackingPosition = positionsAttackedByPlayerTwo[0]; 
        let proofleaf = await battleshipStorageInstance.generateProof(
            playerOne, attackingPosition.axisY, attackingPosition.axisX);

        console.log("playerTwo perform the 1° attack");
        console.log("attackingPosition.axisX:", attackingPosition.axisX);
        console.log("attackingPosition.axisY:", attackingPosition.axisY);
        console.log("-----------------------------------------------");

        // playerTwo perform the 1° attack
        let attackResult = await battleshipInstance.attack(
            battleId, proofleaf, attackingPosition.axisX, attackingPosition.axisY,
            { from: playerTwo });

        try {
            await battleshipStorageInstance.setPositionsAttackedByBattleIdAndPlayer(
                battleId, playerTwo, 1, 1, playerTwo);

        } catch (error) {
            // handle the requirment #3
            if (error.message.includes("The player that call this function should be different each time")) {
                console.log("Caught expected error: The player that call this function should be different each time");
            } else {
                throw error;
            }
        }

        const initialTime = Math.floor(Date.now() / 1000); // Get current timestamp in seconds
        const delaySeconds = 5; // 5 seconds (adjust as needed)
        const endTime = initialTime + delaySeconds;

        console.log("Waiting for the time delay...");

        // Check if playerOne's deposit has been frozen
        const playerOneBalanceBeforePenalty = await web3.eth.getBalance(playerOne);

        while (Math.floor(Date.now() / 1000) < endTime) {
            await sleep(1000); // Wait for 1 second before checking again
        }

        console.log("Time delay has elapsed.");

        // ------------------------------------------------------------------
        // playerOne perform the 1° attack
        attackingPosition = positionsAttackedByPlayerOne[0];
        proof = await battleshipStorageInstance.getMerkleTreeProof(playerTwo);
        proofleaf = await battleshipStorageInstance.generateProof(
            playerTwo, attackingPosition.axisY, attackingPosition.axisX);
        proof = await battleshipStorageInstance.getMerkleTreeProof(playerOne);
        
        console.log("playerOne perform the 1° attack after the time is elapsed");
        
        attackResult = await battleshipInstance.attack(
            battleId, proofleaf, attackingPosition.axisX, attackingPosition.axisY, 
            { from: playerOne });

        // handle the requirment #5
        if (attackResult.receipt.logs.length > 0) {
            // Detect the PlayerCheating event
            assert.equal(attackResult.receipt.logs[0].event, 
                "StakeFrozen", "Expected StakeFrozen event for playerOne");
            assert.equal(attackResult.receipt.logs[1].event, 
                "StakeRefunded", "Expected StakeRefunded event for playerOne");
            assert.equal(attackResult.receipt.logs[2].event, 
                "PenaltyApplied", "Expected PenaltyApplied event for playerOne");
            console.log("All the events that indicates that the time is elapsed, are correctly emitted");
        } else {
            // Handle the case where there are no logs
            assert.fail("Expected differents event, but no events were emitted");
        }
        
    }); 

    function sleep(ms) {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

});