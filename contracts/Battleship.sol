// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
pragma abicoder v2;
// Web3.js v1.10.0

/** Commands to set-up the initial environment:
    npm install solc@0.8.19
    **/

/** Commands to Run code:
    truffle migrate  --> to complile and deploy the contract
    **/

import "./interfaces/IntBattleshipStorage.sol";
import "./interfaces/IntBattleshipStruct.sol";
//import "./interfaces/IntBattleshipLogic.sol";
import "./libs/MerkleProof.sol";
//import "./libs/Strings.sol";

contract Battleship is IntBattleshipStruct, MerkleProof {

    IntBattleshipStorage dataStorage;
    MerkleProof merkleProof;
    //IntBattleshipLogic gameLogic;
    address owner;

    constructor(address _dataStorage) {
        dataStorage = IntBattleshipStorage(_dataStorage);
        merkleProof = new MerkleProof();
        owner = dataStorage.msgSender();
        //gameLogic = IntBattleshipLogic(_gameLogicAddress);
    }
    
    event PlayerJoinedLobby(address _playerAddress, GamePhase _gamePhase);
    event BattleStarted(uint _battleId, GamePhase _gamePhase, address[2] _players);
    event ConfirmShotStatus(uint _battleId, address _confirmingPlayer, address _opponent, uint8[2] _position, ShipPosition _shipDetected);
    event AttackLaunched(uint _battleId, address _launchingPlayer, address _opponent, uint8 _attackingPositionX, uint8 _attackingPositionY);
    event WinnerDetected(uint _battleId, address _winnerAddress, address _opponentAddress);
    event ConfirmWinner(uint _battleId, address _winnerAddress, address _opponentAddress, uint _reward);
    event Transfer(address _to, uint _amount, uint _balance);
    event StakeValue(uint value);
    event Print();

    function emitStackValueFromGamePhase(GamePhase _gamePhase) public {
        //get the Game phase
        GamePhaseDetail memory gamePhaseDetail = dataStorage.getGamePhaseDetails(_gamePhase);
        
         // Emit the stake value
        emit StakeValue(gamePhaseDetail.stake);
    }

    function emitStackValueFromMsgValue() public payable {
        emit StakeValue(msg.value);
    }
    
    
    function joinLobby(GamePhase _gamePhase, bytes32 _root, 
    string memory _encryptedMerkleTree) 
    public payable returns (uint){
        uint deposit = msg.value;
        address player = msg.sender;
        uint battleId = 0;
        

        //get the Game phase
        GamePhaseDetail memory gamePhaseDetail = dataStorage.getGamePhaseDetails(_gamePhase);
        
        //Require that the amount of money sent in greater or equal to the required amount for this mode.
        require(deposit == gamePhaseDetail.stake, "The amount of money deposited must be equal to the staking amount for this game mode");
        
        //Get the Lobby
        LobbyModel memory lobby = dataStorage.getLobbyByGamePhase(_gamePhase);
        
        //require that the sender is not already in the lobby
        require(lobby.occupant != player, "The occupant can not join in as the player");
        
        emit Print();
        
        //Check if there is currenly a player in the lobby
        if(!lobby.isOccupied) 
        {
            lobby.occupant = player;
            lobby.isOccupied = true;
            lobby.positionRoot = _root;
            lobby.encryptedMerkleTree = _encryptedMerkleTree;
            emit PlayerJoinedLobby(player, _gamePhase);

        }else
        {
            //Start a new match
            uint totalStake = gamePhaseDetail.stake * 2;
            battleId = dataStorage.createNewGameId();
            BattleModel memory battle  = BattleModel(totalStake, lobby.occupant, player, block.timestamp, player, false, address(0), _gamePhase, gamePhaseDetail.maxTimeForPlayerToPlay, false, 0, block.timestamp, block.timestamp, false, false);
            
            //Set the encrypted merkle tree for both players
            dataStorage.setEncryptedMerkleTreeByBattleIdAndPlayer(battleId, battle.host, lobby.encryptedMerkleTree);
            dataStorage.setEncryptedMerkleTreeByBattleIdAndPlayer(battleId, battle.client, _encryptedMerkleTree);
            
            //Set the merkle tree root for both players.
            dataStorage.setMerkleTreeRootByBattleIdAndPlayer(battleId, battle.host, lobby.positionRoot);
            dataStorage.setMerkleTreeRootByBattleIdAndPlayer(battleId, battle.client, _root);
            
            //Set the Last Play Time
            //dataStorage.setLastPlayTimeByBattleId(battleId, block.timestamp);
            dataStorage.setTurnByBattleId(battleId, player);

            lobby.occupant = address(0);
            lobby.isOccupied = false;
            lobby.positionRoot = "0x00";
            lobby.encryptedMerkleTree = "";
            dataStorage.updateBattleById(battleId, battle);
            
     
            
            emit BattleStarted(battleId, _gamePhase, [battle.host, battle.client]);

        }
        
        // Update the lobby
        dataStorage.setLobbyByGamePhase(_gamePhase, lobby);
        return battleId;
    }
    
    function getPlayersEncryptedPositions(uint _battleId) public view returns (string memory){
        //Get the ship positions for the battle
        return dataStorage.getEncryptedMerkleTreeByBattleIdAndPlayer(_battleId, msg.sender);
    }

    /*function attack(uint _battleId, string memory _previousPositionLeaf, 
    bytes memory _previousPositionProof, uint8 _attackingPositionX, 
    uint8 _attackingPositionY) public returns (bool){
        BattleModel memory battle = dataStorage.getBattle(_battleId);
        GamePhaseDetail memory gamePhaseDetail = dataStorage.getGamePhaseDetails(battle.gamePhase);
        address player = gameLogic.msgSender();
        address opponent = battle.host == player ? battle.client : battle.host;
        address nextTurn = dataStorage.getTurnByBattleId(_battleId);

        uint8[2] memory previousPositionIndex = dataStorage.getLastFiredPositionIndexByBattleIdAndPlayer(_battleId, opponent);
        bytes32 root = dataStorage.getMerkleTreeRootByBattleIdAndPlayer(_battleId, player);

        // Calculate the index
        uint256 index = (previousPositionIndex[1] * gameLogic.getGridDimensionN()) + previousPositionIndex[0] + 1;

        bool proofValidity;
        ProofVariables memory proofVar = ProofVariables({
                proof: _previousPositionProof,
                rootHash: root,
                previousLeafHash: _previousPositionLeaf,
                index: index
        });

        if (previousPositionIndex[0] == 0) {
            proofValidity = true;
        } else {
            proofValidity = merkleProof.checkProofOrdered(proofVar);
        }

        uint lastPlayTime = dataStorage.getLastPlayTimeByBattleId(_battleId);

        require(!battle.isCompleted, "A winner has been detected. Proceed to verify inputs");
        require((block.timestamp - lastPlayTime) < gamePhaseDetail.maxTimeForPlayerToPlay, "Time to play is expired.");
        require(nextTurn == player, "Wait till next turn");
        require(proofValidity, "The proof and position combination indicates an invalid move");

        // Update the position index to the list of fired locations
        dataStorage.setLastFiredPositionIndexByBattleIdAndPlayer(_battleId, player, _attackingPositionX, _attackingPositionY);

        // Update the turn
        dataStorage.setTurnByBattleId(_battleId, opponent);

        // Set the position index to the list of fired locations
        dataStorage.setPositionsAttackedByBattleIdAndPlayer(_battleId, player, _attackingPositionX, _attackingPositionY);

        // Get the status of the position hit
        string memory statusOfLastposition = _previousPositionLeaf;
        ShipPosition memory shipPosition = gameLogic.getShipPosition(statusOfLastposition);

        // Emit an event containing more details about the last shot fired
        emit ConfirmShotStatus(_battleId, player, opponent, previousPositionIndex, shipPosition);

        // Emit an event indicating that an attack has been launched
        emit AttackLaunched(_battleId, player, opponent, _attackingPositionX, _attackingPositionY);

        // Check if we have a winner
        checkForWinner(_battleId, player, opponent, shipPosition);

        return true;
    }*/

    function attack(uint _battleId, uint8 _previousPositionLeaf,
    bytes memory _previousPositionProof, uint8 _attackingPositionX,
    uint8 _attackingPositionY) public returns (bool) {
        BattleModel memory battle = dataStorage.getBattle(_battleId);
        GamePhaseDetail memory gamePhaseDetail = dataStorage.getGamePhaseDetails(battle.gamePhase);
        address player = dataStorage.msgSender();
        address opponent = battle.host == player ? battle.client : battle.host;
        address nextTurn = dataStorage.getTurnByBattleId(_battleId);
        uint lastPlayTime = dataStorage.getLastPlayTimeByBattleId(_battleId);

        require(!battle.isCompleted, "A winner has been detected. Proceed to verify inputs");
        require((block.timestamp - lastPlayTime) < gamePhaseDetail.maxTimeForPlayerToPlay, "Time to play is expired.");
        require(nextTurn == player, "Wait till next turn");

        // Get the status of the position hit
        ShipPosition memory shipPosition = dataStorage.getShipPosition(_previousPositionLeaf);
        ProofVariables memory proofVar;

        {   
            uint batID = _battleId;
            bytes memory prevPosProof = _previousPositionProof;
            proofVar = getProofVariables(batID, player, opponent, _previousPositionLeaf, prevPosProof, shipPosition);
        }

        require(merkleProof.checkProofOrdered(proofVar), "The proof and position combination indicates an invalid move");

        updatePositionIndices(_battleId, player, _attackingPositionX, _attackingPositionY, opponent);

        // Emit an event indicating that an attack has been launched
        emit AttackLaunched(_battleId, player, opponent, _attackingPositionX, _attackingPositionY);

        checkForWinner(_battleId, player, opponent, shipPosition);

        return true;
    }

function getProofVariables(uint _battleId, address player, address opponent, uint8 _previousPositionLeaf, 
bytes memory _previousPositionProof, ShipPosition memory _shipPosition) internal returns (ProofVariables memory) {
    uint8[2] memory previousPositionIndex = dataStorage.getLastFiredPositionIndexByBattleIdAndPlayer(_battleId, opponent);
    bytes32 root = dataStorage.getMerkleTreeRootByBattleIdAndPlayer(_battleId, player);
    uint256 index = (previousPositionIndex[1] * dataStorage.getGridDimensionN()) + previousPositionIndex[0] + 1;

    // Emit an event containing more details about the last shot fired
    emit ConfirmShotStatus(_battleId, player, opponent, previousPositionIndex, _shipPosition);
    return ProofVariables({
        proof: _previousPositionProof,
        rootHash: root,
        previousLeafHash: _previousPositionLeaf,
        index: index
    });
}
    // Update the position index to the list of fired locations, 
    // update the turn and set the position index to the list of fired locations
    function updatePositionIndices(uint _battleId, address player, uint8 _attackingPositionX,
    uint8 _attackingPositionY, address opponent) internal {
        dataStorage.setLastFiredPositionIndexByBattleIdAndPlayer(_battleId, player, _attackingPositionX, _attackingPositionY);
        dataStorage.setTurnByBattleId(_battleId, opponent);
        dataStorage.setPositionsAttackedByBattleIdAndPlayer(_battleId, player, _attackingPositionX, _attackingPositionY);
    }
    
    function getPositionsAttacked(uint _battleId, address _player) public view returns(uint8[] memory){
        return dataStorage.getPositionsAttackedByBattleIdAndPlayer(_battleId, _player);
    }
    
    //Checks if there is a winner in the game.
    function checkForWinner(uint _battleId, address _playerAddress, address _opponentAddress, ShipPosition memory _shipPosition) private returns (bool){
        //Add to the last position hit
        if(_shipPosition.state != ShipState.None) dataStorage.setCorrectPositionsHitByBattleIdAndPlayer(_battleId, _playerAddress, _shipPosition);
        
        //Get The total positions hit
        ShipPosition[] memory correctPositionsHit = dataStorage.getCorrectPositionsHitByBattleIdAndPlayer(_battleId, _playerAddress);
        
        if(correctPositionsHit.length == dataStorage.getSumOfShipSize())
        {
            //A winner has been found. Call  the game to a halt, and let the verification process begin.
            BattleModel memory battle = dataStorage.getBattle(_battleId);
            battle.isCompleted = true;
            battle.winner = _playerAddress;
            dataStorage.updateBattleById(_battleId, battle);
            emit WinnerDetected(_battleId, _playerAddress, _opponentAddress);
        }
        
        return true;
    }

    
    function collectReward(uint _battleId) public returns (bool)
    {
        BattleModel memory battle = dataStorage.getBattle(_battleId);
        address playerAddress = dataStorage.msgSender();
        GamePhaseDetail memory gamePhaseDetail = dataStorage.getGamePhaseDetails(battle.gamePhase);
        address transactionOfficer = address(dataStorage.getTransactionOfficer());

        require(battle.isCompleted, "Battle is not yet completed");
        require(battle.winner == playerAddress, "Only the suspected winner of the battle can access this function");
        require(battle.leafVerificationPassed, "Leaf verification has to be passed first");
        require(battle.shipPositionVerificationPassed, "Ship Positions Verification has to be passed");
        
        
         //Get the total reward.
        uint totalReward = gamePhaseDetail.stake *  2;
        uint transactionCost = 0;
        uint commission = 0;
        uint actualReward = totalReward - transactionCost - commission;
        
        transfer(playerAddress, actualReward);
        transfer(transactionOfficer, transactionCost);
        transfer(owner, commission);
        
        return true;
    }
    
  
    function transfer(address _recipient, uint _amount) private 
     {
         (bool success, ) = _recipient.call{value : _amount}("");
         require(success, "Transfer failed.");
         emit Transfer(_recipient, _amount, address(this).balance);
     }
  
 }