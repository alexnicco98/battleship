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
import "./libraries/IntBattleshipStruct.sol";

contract Battleship {

    IntBattleshipStorage dataStorage;
    address public currentPlayer;
    address owner;
    uint deposit;
    mapping(uint256 => mapping(address => mapping(string => bool))) myMapping;

    constructor(address _dataStorage) {
        dataStorage = IntBattleshipStorage(_dataStorage);
        owner = dataStorage.msgSender();
    }

    modifier onlyCurrentPlayer() {
        string memory text = string(abi.encodePacked("Battleship: Only the current player can execute this transaction ", addressToString(msg.sender)));
        require(msg.sender == currentPlayer, text);
        _;
    }
    
    event PlayerJoinedLobby(address _playerAddress, IntBattleshipStruct.GamePhase _gamePhase);
    event PlayerCreatedLobby(address _playerAddress);
    event BattleStarted(uint256 _battleId, IntBattleshipStruct.GamePhase _gamePhase, address[2] _players);
    event ConfirmShotStatus(uint256 _battleId, address _confirmingPlayer, 
        address _opponent, uint8[2] _position, IntBattleshipStruct.ShipPosition _shipDetected);
    event AttackLaunched(uint256 _battleId, address _launchingPlayer, 
        address _opponent, uint8 _attackingPositionX, uint8 _attackingPositionY);
    event WinnerDetected(uint256 _battleId, address _winnerAddress, 
        address _opponentAddress);
    event ConfirmWinner(uint256 _battleId, address _winnerAddress, 
        address _opponentAddress, uint _reward);
    event PenaltyApplied(uint256 _battleId, address _player, uint256 _penaltyAmount);
    event StakeFrozen(uint256 _battleId, address _player, uint256 _stake);
    event StakeRefunded(uint256 _battleId, address _opponent, uint256 _refundedAmount);
    event Transfer(address _to, uint256 _amount, uint256 _balance);
    event StakeValue(uint256 _value);
    event LogMessage(string _message);

    function emitStackValueFromGamePhase(IntBattleshipStruct.GamePhase _gamePhase) public {
        //get the Game phase
        IntBattleshipStruct.GamePhaseDetail memory gamePhaseDetail = dataStorage.getGamePhaseDetails(_gamePhase);
        
         // Emit the stake value
        emit StakeValue(gamePhaseDetail.stake);
    }

    function emitStackValueFromMsgValue() public payable {
        emit StakeValue(msg.value);
    }

    function createLobby(IntBattleshipStruct.GamePhase _gamePhase, bytes32 _root) 
    public payable returns (uint256){
        deposit = msg.value;
        address player = msg.sender;
        uint256 battleId = 0;

        // get the Game phase
        IntBattleshipStruct.GamePhaseDetail memory gamePhaseDetail = dataStorage.getGamePhaseDetails(_gamePhase);
        
        // Require that the amount of money sent in greater or 
        // equal to the required amount for this mode.
        require(deposit == gamePhaseDetail.stake, 
            "The amount of money deposited must be equal to the staking amount for this game mode");
        
        //Get the Lobby
        IntBattleshipStruct.LobbyModel memory lobby = IntBattleshipStruct.LobbyModel({isOccupied: true, 
            occupant: player, playerOneRootHash: _root, playerTwoRootHash: 0x00
        });

        emit PlayerCreatedLobby(player);

        // Update the lobby
        dataStorage.setLobbyByAddress(player, lobby);
        return battleId;
    }

    function joinLobby(address _creatorAddress, IntBattleshipStruct.GamePhase _gamePhase, bytes32 _root) 
    public payable returns (uint256){
        uint _deposit = msg.value;
        address player = msg.sender;
        uint256 battleId = 0;

        // Get the Game phase
        IntBattleshipStruct.GamePhaseDetail memory gamePhaseDetail = dataStorage.getGamePhaseDetails(_gamePhase);

        // Require that the amount of money sent in greater or 
        // equal to the required amount for this mode.
        require(_deposit == gamePhaseDetail.stake, 
            "The amount of money deposited must be equal to the staking amount for this game mode");
        require(_deposit == deposit, 
            "The amount of money deposited must be equal for both players");

        // Get the Lobby 
        IntBattleshipStruct.LobbyModel memory lobby = dataStorage.getLobbyByAddress(_creatorAddress);

        // Require that the sender is not already in the lobby
        require(lobby.occupant != player, "The occupant can not join in as the player");
        
        // Check if there is currenly a player in the lobby
        require(lobby.isOccupied == true, "There is a player in the lobby");

        // Start a new match
        uint totalStake = gamePhaseDetail.stake * 2;
        battleId = dataStorage.createNewGameId();
        IntBattleshipStruct.BattleModel memory battle  = IntBattleshipStruct.BattleModel(totalStake, lobby.occupant, player, 
            block.timestamp, player, false, false, false, address(0), IntBattleshipStruct.GamePhase.Shooting, 
            gamePhaseDetail.maxTimeForPlayerToPlay, false, 0, block.timestamp, 
            block.timestamp, false, false);       
        
        // Set the merkle tree root for both players.
        dataStorage.setMerkleTreeRootByBattleIdAndPlayer(battleId, battle.host, lobby.playerOneRootHash);
        dataStorage.setMerkleTreeRootByBattleIdAndPlayer(battleId, battle.client, _root);
        
        //Set the Last Play Time
        dataStorage.setLastPlayTimeByBattleId(battleId, block.timestamp);
        dataStorage.setTurnByBattleId(battleId, player);

        // Update the lobby
        lobby.playerTwoRootHash = _root;
        dataStorage.setLobbyByAddress(_creatorAddress, lobby);
        dataStorage.updateBattleById(battleId, battle, IntBattleshipStruct.GamePhase.Shooting);

        // Initialize the current player
        currentPlayer = player;
        
        emit BattleStarted(battleId, IntBattleshipStruct.GamePhase.Shooting, [battle.host, battle.client]);
        
        return battleId;
    }

    function attack(uint256 _battleId, bytes32[] memory _proofLeaf, uint8 _attackingPositionX, 
    uint8 _attackingPositionY) public returns (bool){
        IntBattleshipStruct.BattleModel memory battle = dataStorage.getBattle(_battleId);
        IntBattleshipStruct.GamePhaseDetail memory gamePhaseDetail = dataStorage.getGamePhaseDetails(
            battle.gamePhase);
        address player = msg.sender;
        address opponent = battle.host == player ? battle.client : battle.host;
        address nextTurn = dataStorage.getTurnByBattleId(_battleId);
        uint8[2] memory previousPositionIndex = [_attackingPositionY, _attackingPositionX];
        bool proofValidity = false;

        proofValidity = dataStorage.verifyProof(_proofLeaf, opponent, 
            _attackingPositionY, _attackingPositionX);

        uint256 lastPlayTime = dataStorage.getLastPlayTimeByBattleId(_battleId);
        uint256 currentTime = block.timestamp;
        uint256 timeElapsed = currentTime - lastPlayTime;

        if (timeElapsed > gamePhaseDetail.maxTimeForPlayerToPlay) {
            
            // Freeze the deposit
            freezeDeposit(_battleId, player);

            // Emit an event indicating the penalty
            emit PenaltyApplied(_battleId, player, gamePhaseDetail.penaltyAmount);
            
            return false;
        }

        require(!battle.isCompleted, "A winner has been detected. Proceed to verify inputs");
        require(nextTurn == player, "Wait till next turn");
        require(proofValidity, "The proof and position combination indicates an invalid move");

        // Update the position index to the list of fired locations
        dataStorage.setPositionsAttackedByBattleIdAndPlayer(_battleId, player, 
            _attackingPositionX, _attackingPositionY, currentPlayer);

        // Update the turn
        dataStorage.setTurnByBattleId(_battleId, opponent);

        // Switch turns
        currentPlayer = opponent;

        // Get the status of the position hit
        IntBattleshipStruct.ShipPosition memory shipPosition = dataStorage.getShipPositionByAxis(opponent, 
            _attackingPositionX, _attackingPositionY);

        /*string memory text = string(abi.encodePacked("player: ", addressToString(player) , ", positions that cause the cheat,axisX: ", 
                    uintToString(shipPosition.axisX), ", axisY: ", uintToString(shipPosition.axisY)));
        emit LogMessage(text);*/

        // Emit an event containing more details about the last shot fired
        emit ConfirmShotStatus(_battleId, player, opponent, previousPositionIndex, 
            shipPosition);

        // Emit an event indicating that an attack has been launched
        emit AttackLaunched(_battleId, player, opponent, _attackingPositionX, 
            _attackingPositionY);

        // Check if we have a winner
        checkForWinner(_battleId, player, opponent, shipPosition);

        return true;
    }

    function freezeDeposit(uint256 _battleId, address _player) internal {
        IntBattleshipStruct.BattleModel memory battle = dataStorage.getBattle(_battleId);
        IntBattleshipStruct.GamePhaseDetail memory gamePhaseDetail = dataStorage.getGamePhaseDetails(battle.gamePhase);

        // Ensure that the player has a stake to freeze
        require(gamePhaseDetail.stake > 0, "No stake to freeze.");

        // Freeze the player's stake
        if (_player == battle.host) {
            // Player is the host, freeze the host's stake
            battle.hostStakeFrozen = true;
        } else if (_player == battle.client) {
            // Player is the client, freeze the client's stake
            battle.clientStakeFrozen = true;
        } else {
            // Invalid player address
            revert("Invalid player address.");
        }

        // Refund the opponent's stake
        address opponent = (_player == battle.host) ? battle.client : battle.host;
        // Ensure that the opponent's stake is not already frozen
        require(!(battle.hostStakeFrozen && battle.clientStakeFrozen), "Both players' stakes are frozen.");
        
        // Transfer the opponent's stake back to them
        (bool success, ) = opponent.call{value: gamePhaseDetail.stake}("");
        require(success, "Transfer failed.");

        // Emit events to log the freezing and refunding of stakes
        emit StakeFrozen(_battleId, _player, gamePhaseDetail.stake);
        emit StakeRefunded(_battleId, opponent, gamePhaseDetail.stake);
    }


    function getPositionsAttacked(uint _battleId, address _player) 
    public view returns(uint8[2] memory){
        return dataStorage.getLastPositionsAttackedByBattleIdAndPlayer(_battleId, _player);
    }
    
    // Checks if there is a winner in the game
    function checkForWinner(uint _battleId, address _playerAddress, address _opponentAddress, 
    IntBattleshipStruct.ShipPosition memory _shipPosition) private returns (bool){
        // Add to the last position hit
        if(_shipPosition.state != IntBattleshipStruct.ShipState.None){ 
            dataStorage.setCorrectPositionsHitByBattleIdAndPlayer(_battleId, 
            _playerAddress, _shipPosition);
        }
        
        // Get The total positions hit
        IntBattleshipStruct.ShipPosition[] memory correctPositionsHit = dataStorage.
        getCorrectPositionsHitByBattleIdAndPlayer(_battleId, _playerAddress);
        uint8[2][] memory correctPositionsAttacked = dataStorage.getAllPositionsAttacked(_battleId, _playerAddress);
        IntBattleshipStruct.BattleModel memory battle = dataStorage.getBattle(_battleId);
        
        if(correctPositionsHit.length == dataStorage.getSumOfShipSize()){
            // check if the positions are valid
            if (!areAllPositionsUnique(correctPositionsAttacked, _playerAddress, _battleId)) {
                // Freeze the deposit
                freezeDeposit(_battleId, _playerAddress);
                
                IntBattleshipStruct.GamePhaseDetail memory gamePhaseDetail = dataStorage.getGamePhaseDetails(
                    battle.gamePhase);
                // Emit an event indicating the penalty
                emit PenaltyApplied(_battleId, _playerAddress, gamePhaseDetail.penaltyAmount);

                // Tho opposite player win, because the player cheat
                battle.isCompleted = true;
                battle.winner = _opponentAddress;
                dataStorage.updateBattleById(_battleId, battle, IntBattleshipStruct.GamePhase.Gameover);
                emit WinnerDetected(_battleId, _opponentAddress, _playerAddress);
                
                //return false;
            }else{ // A winner has been found, and the positions are valid
                battle.isCompleted = true;
                battle.winner = _playerAddress;
                dataStorage.updateBattleById(_battleId, battle, IntBattleshipStruct.GamePhase.Gameover);
                collectReward(_battleId);
                emit WinnerDetected(_battleId, _playerAddress, _opponentAddress);
            }
        }
        
        return true;
    }

    // Check if all positions in an array are unique
    function areAllPositionsUnique(uint8[2][] memory _correctPositionsAttacked, 
    address _player, uint256 _battleId) private returns (bool) {

        for (uint i = 0; i < _correctPositionsAttacked.length; i++) {
            string memory positionKey = string(abi.encodePacked(uintToString(_correctPositionsAttacked[i][0]), "-", uintToString(_correctPositionsAttacked[i][1])));
            /*string memory text = string(abi.encodePacked("positions that cause the cheat,axisX: ", 
                    uintToString(positions[i].axisX), ", axisY: ", uintToString(positions[i].axisY), ", positionKey: ", positionKey));
                emit LogMessage(text);*/
            if (myMapping[_battleId][_player][positionKey]) {
                // This position combination has been seen before, not all positions are unique
                return false;
            }
            myMapping[_battleId][_player][positionKey] = true;
        }

        // All position combinations are unique
        return true;
    }
    
    function collectReward(uint _battleId) public returns (bool){
        IntBattleshipStruct.BattleModel memory battle = dataStorage.getBattle(_battleId);
        address playerAddress = msg.sender;
        IntBattleshipStruct.GamePhaseDetail memory gamePhaseDetail = dataStorage.getGamePhaseDetails(battle.gamePhase);

        require(battle.isCompleted, "Battle is not yet completed");
        require(battle.winner == playerAddress, 
            "Only the suspected winner of the battle can access this function");
        
        // Get the total reward
        uint totalReward = gamePhaseDetail.stake *  2;
        transfer(playerAddress, totalReward);
        
        return true;
    }
  
    function transfer(address _recipient, uint _amount) private {
         (bool success, ) = _recipient.call{value : _amount}("");
         require(success, "Transfer failed.");
         emit Transfer(_recipient, _amount, address(this).balance);
    }

    function uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint8(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    // Helper function to convert address to string
    function addressToString(address addr) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(addr)));
        return bytes32ToString(value);
    }

    // Helper function to convert bytes32 to string
    function bytes32ToString(bytes32 value) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";
        bytes memory str = new bytes(64);
        for (uint256 i = 0; i < 32; i++) {
            str[i * 2] = alphabet[uint8(value[i] >> 4)];
            str[i * 2 + 1] = alphabet[uint8(value[i] & 0x0f)];
        }
        return string(str);
    }
  
 }