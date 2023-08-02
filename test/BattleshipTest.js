const Battleship = artifacts.require("Battleship");
const IDataStorageSchema = artifacts.require("IDataStorageSchema");
const ShipType = IDataStorageSchema.ShipType;
const AxisType = IDataStorageSchema.AxisType;
const GameMode = IDataStorageSchema.GameMode;

contract("Battleship", accounts => {

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
        let playerOneRootHash = "0xd22a8a4496b2d49a0a6c777d74a404c200dc24f99916fdfe5a72807b3355512e";
        let playerTwoRootHash = "0x00871c4adab8e33d738b4555dbe16b70d1deab3bce2ec8a0fd215ab79e5ba275";
        let gameMode = GameMode.Regular;

        return Battleship.deployed()
        .then(instance => {
            battleship = instance;
            let valueInWei = 1000000000000000;
            return instance.joinLobby(gameMode, playerOneRootHash, encryptedMerkleTree, { from: playerOne, value: valueInWei });
        })
        .then(result => {
            assert.equal(result.logs[0].event, "PlayerJoinedLobby", "Event must indicate that a player has joined the lobby");
            assert.equal(result.logs[0].args._player, playerOne, "Creator account is not valid");
            assert.equal(result.logs[0].args._gameMode.valueOf(), gameMode, "Game mode is not valid");

            let valueInWei = 1000000000000000;
            return battleship.joinLobby(gameMode, playerTwoRootHash, encryptedMerkleTree, { from: playerTwo, value: valueInWei });
        })
        .then(result => {
            battleId = result.logs[0].args._battleId;
            let players = result.logs[0].args._players;
            let gameMode = result.logs[0].args._gameMode.valueOf();

            // Check that the BattleStarted Event is emitted
            assert.equal(result.logs[0].event, "BattleStarted", "Event must indicate that a battle has started");

            // Check if both players are included in the event log for the battle
            assert.equal(players.includes(playerOne) && players.includes(playerTwo), true, "Battle must include both players");

            // Check that the game mode is equal to the game mode entered by the initial player and also equal to the game mode entered by the current player
            assert.equal(gameMode == gameMode, true, "Game mode must be equal to the starting game mode for the Match/Lobby");
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
        let previousPositionLeaf = "00000";
        let previousPositionProof = "0x00";
        let attackingPosition = 1;

        return battleship.attack(battleId, previousPositionLeaf, previousPositionProof, attackingPosition, { from: playerTwo })
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
            assert.equal(confirmShotStatusEvent.args._shipDetected.ship, ShipType.None, "Previous Ship type must be of type none because this is the first attack to be launched");
            assert.equal(confirmShotStatusEvent.args._shipDetected.axis, AxisType.None, "Previous ship type type must be of Axis type none because this is the first attack to be launched");

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
});