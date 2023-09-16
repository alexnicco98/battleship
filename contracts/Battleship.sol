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
//import "./BattleshipStorage.sol";
//import "./libs/Strings.sol";

contract Battleship {

    IntBattleshipStorage dataStorage;
    address public currentPlayer;
    //IntBattleshipLogic gameLogic;
    address owner;
    uint deposit;

    constructor(address _dataStorage) {
        dataStorage = IntBattleshipStorage(_dataStorage);
        owner = dataStorage.msgSender();
        //gameLogic = IntBattleshipLogic(_gameLogicAddress);
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
    event Transfer(address _to, uint256 _amount, uint256 _balance);
    event StakeValue(uint256 _value);
    event Print();
    event LogMessage(string _message);
    event shipsToString(string[] _ship);

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
        IntBattleshipStruct.LobbyModel memory lobby = IntBattleshipStruct.LobbyModel({isOccupied: true, occupant: player,
            playerOneRootHash: _root, playerTwoRootHash: 0x00
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

        //get the Game phase
        IntBattleshipStruct.GamePhaseDetail memory gamePhaseDetail = dataStorage.getGamePhaseDetails(_gamePhase);

        // Require that the amount of money sent in greater or 
        // equal to the required amount for this mode.
        require(_deposit == gamePhaseDetail.stake, 
            "The amount of money deposited must be equal to the staking amount for this game mode");
        require(_deposit == deposit, 
            "The amount of money deposited must be equal for both players");

        //Get the Lobby 
        IntBattleshipStruct.LobbyModel memory lobby = dataStorage.getLobbyByAddress(_creatorAddress);

        //require that the sender is not already in the lobby
        require(lobby.occupant != player, "The occupant can not join in as the player");
        
        // Check if there is currenly a player in the lobby
        require(lobby.isOccupied == true, "There is a player in the lobby");

        //Start a new match
        uint totalStake = gamePhaseDetail.stake * 2;
        battleId = dataStorage.createNewGameId();
        IntBattleshipStruct.BattleModel memory battle  = IntBattleshipStruct.BattleModel(totalStake, lobby.occupant, player, 
            block.timestamp, player, false, address(0), IntBattleshipStruct.GamePhase.Shooting, 
            gamePhaseDetail.maxTimeForPlayerToPlay, false, 0, block.timestamp, 
            block.timestamp, false, false);       
        
        //Set the encrypted merkle tree for both players
        /*dataStorage.setMerkleTreeRootByBattleIdAndPlayer(battleId, battle.host, 
            lobby.playerOneRootHash);
        dataStorage.setMerkleTreeRootByBattleIdAndPlayer(battleId, battle.client, 
            _root);*/   
        
        //Set the merkle tree root for both players.
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
        //dataStorage.setCurrentPlayer(player);
        
        emit BattleStarted(battleId, IntBattleshipStruct.GamePhase.Shooting, [battle.host, battle.client]);
        
        return battleId;
    }

    function attack(uint256 _battleId, bytes32[] memory _proofLeaf,
    uint8 _attackingPositionX, uint8 _attackingPositionY) public onlyCurrentPlayer returns (bool){
        
        IntBattleshipStruct.BattleModel memory battle = dataStorage.getBattle(_battleId);
        IntBattleshipStruct.GamePhaseDetail memory gamePhaseDetail = dataStorage.getGamePhaseDetails(
            battle.gamePhase);
        address player = msg.sender;
        address opponent = battle.host == player ? battle.client : battle.host;
        address nextTurn = dataStorage.getTurnByBattleId(_battleId);

        /*uint8[2] memory previousPositionIndex = dataStorage.
            getLastPositionsAttackedByBattleIdAndPlayer(_battleId, player);*/
        uint8[2] memory previousPositionIndex = [_attackingPositionY, _attackingPositionX];
        //bytes32 root = dataStorage.getMerkleTreeRootByBattleIdAndPlayer(_battleId, opponent);

        /*emit LogMessage(string(abi.encodePacked("proof: ", bytes32ToString(
            _currentPositionLeaf), ", rootHash: ", bytes32ToString(root), 
            ", proofLeafHash: ", bytes32ToString(_proofLeaf), ", indexY: ", 
            uintToString(previousPositionIndex[0]), ", indexX: ", 
            uintToString(previousPositionIndex[1]))));*/

        //uint256 len = dataStorage.getPositionsAttackedLength(_battleId, player);
        
        bool proofValidity = false;
        /*if ( len == 0) {
            proofValidity = true;
        } else {
            
            
            //PlayerModel memory playerModel = dataStorage.getPlayerByAddress(opponent);
            //proof = merkleProof.createProof(_currentPositionLeaf,
            //_previousPositionLeaf, _previousPositionIndex);
            //dataStorage.setProofByIndexAndPlayer(_previousPositionIndex, player, proof);
            
            
        }
        ProofVariables memory proofVar = ProofVariables({
                proof: _proofLeaf,
                root: root,
                leaf: _currentPositionLeaf,
                index: previousPositionIndex
            });*/
        proofValidity = dataStorage.verifyProof(_proofLeaf, opponent, 
            _attackingPositionY, _attackingPositionX);

        uint256 lastPlayTime = dataStorage.getLastPlayTimeByBattleId(_battleId);

        require(!battle.isCompleted, "A winner has been detected. Proceed to verify inputs");
        require((block.timestamp - lastPlayTime) < gamePhaseDetail.maxTimeForPlayerToPlay, 
            "Time to play is expired.");
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

        function getPositionsAttacked(uint _battleId, address _player) 
    public view returns(uint8[2] memory){
        return dataStorage.getLastPositionsAttackedByBattleIdAndPlayer(_battleId, _player);
    }
    
    //Checks if there is a winner in the game.
    function checkForWinner(uint _battleId, address _playerAddress, address _opponentAddress, 
    IntBattleshipStruct.ShipPosition memory _shipPosition) private returns (bool){
        //Add to the last position hit
        if(_shipPosition.state != IntBattleshipStruct.ShipState.None) dataStorage.
            setCorrectPositionsHitByBattleIdAndPlayer(_battleId, 
            _playerAddress, _shipPosition);
        
        //Get The total positions hit
        IntBattleshipStruct.ShipPosition[] memory correctPositionsHit = dataStorage.
        getCorrectPositionsHitByBattleIdAndPlayer(_battleId, _playerAddress);

        // DEBUG
        //convertAndEmitShipPositions(correctPositionsHit);
        
        if(correctPositionsHit.length == dataStorage.getSumOfShipSize()){
            // A winner has been found. Call the game to a halt, 
            // and let the verification process begin.
            IntBattleshipStruct.BattleModel memory battle = dataStorage.getBattle(_battleId);
            battle.isCompleted = true;
            battle.winner = _playerAddress;
            dataStorage.updateBattleById(_battleId, battle, IntBattleshipStruct.GamePhase.Gameover);
            emit WinnerDetected(_battleId, _playerAddress, _opponentAddress);
        }
        
        return true;
    }
    
    function collectReward(uint _battleId) public returns (bool){
        IntBattleshipStruct.BattleModel memory battle = dataStorage.getBattle(_battleId);
        address playerAddress = msg.sender;
        IntBattleshipStruct.GamePhaseDetail memory gamePhaseDetail = dataStorage.getGamePhaseDetails(battle.gamePhase);
        //address transactionOfficer = address(dataStorage.getTransactionOfficer());

        require(battle.isCompleted, "Battle is not yet completed");
        require(battle.winner == playerAddress, 
            "Only the suspected winner of the battle can access this function");
        //require(battle.leafVerificationPassed, "Leaf verification has to be passed first");
        //require(battle.shipPositionVerificationPassed, 
        //   "Ship Positions Verification has to be passed");
        
        
         //Get the total reward.
        uint totalReward = gamePhaseDetail.stake *  2;
        //uint transactionCost = 0;
        //uint commission = 0;
        //uint actualReward = totalReward - transactionCost - commission;
        
        transfer(playerAddress, totalReward);
        //transfer(transactionOfficer, transactionCost);
        //transfer(owner, commission);
        
        return true;
    }
  
    function transfer(address _recipient, uint _amount) private {
         (bool success, ) = _recipient.call{value : _amount}("");
         require(success, "Transfer failed.");
         emit Transfer(_recipient, _amount, address(this).balance);
    }

    function logMyMessage(string memory message) public {
        emit LogMessage(message);
    }

    function lobbyModelToString(IntBattleshipStruct.LobbyModel memory lobby) internal pure returns (string memory) {
        string memory result;

        // Convert boolean to string
        result = string(abi.encodePacked(result, lobby.isOccupied ? "1" : "0"));

        // Convert address to string
        result = string(abi.encodePacked(result, addressToString(lobby.occupant)));

        // Convert bytes32 to string
        result = string(abi.encodePacked(result, bytes32ToString(lobby.playerOneRootHash)));

        // Append encryptedMerkleTree
        result = string(abi.encodePacked(result, lobby.playerTwoRootHash));

        return result;
    }

    function convertAndEmitShipPositions(IntBattleshipStruct.ShipPosition[] memory shipPositions) public {
        string[] memory shipPositionStrings = new string[](shipPositions.length);

        for (uint256 i = 0; i < shipPositions.length; i++) {
            IntBattleshipStruct.ShipPosition memory position = shipPositions[i];
            string memory positionString = string(
                abi.encodePacked(
                    "Ship ", 
                    uintToString(position.shipLength), 
                    " at (", 
                    uintToString(position.axisX), 
                    ",", 
                    uintToString(position.axisY), 
                    ") with direction ", 
                    shipDirectionToString(position.direction)
                )
            );
            shipPositionStrings[i] = positionString;
        }

        emit shipsToString(shipPositionStrings);
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

    function shipDirectionToString(IntBattleshipStruct.ShipDirection direction) internal pure returns (string memory) {
        if (direction == IntBattleshipStruct.ShipDirection.Horizontal) {
            return "Horizontal";
        } else if (direction == IntBattleshipStruct.ShipDirection.Vertical) {
            return "Vertical";
        } else {
            return "Unknown";
        }
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

    // functions to support the App.js
    function getShipDirectionHor() public pure returns (IntBattleshipStruct.ShipDirection){
       return IntBattleshipStruct.ShipDirection.Horizontal; 
    }

    function getShipDirectionVer() public pure returns (IntBattleshipStruct.ShipDirection){
       return IntBattleshipStruct.ShipDirection.Vertical; 
    }

    function getGamePhasePlac()
    public pure returns (IntBattleshipStruct.GamePhase){
        return IntBattleshipStruct.GamePhase.Placement;
    }

    /*function attack(uint _battleId, uint8 _previousPositionLeaf,
    bytes memory _previousPositionProof, uint8 _attackingPositionX,
    uint8 _attackingPositionY) public returns (bool) {
        BattleModel memory battle = dataStorage.getBattle(_battleId);
        GamePhaseDetail memory gamePhaseDetail = 
            dataStorage.getGamePhaseDetails(battle.gamePhase);
        
        //address player = dataStorage.msgSender();
        address player = msg.sender;
        address opponent = battle.host == player ? battle.client : battle.host;
        address nextTurn = dataStorage.getTurnByBattleId(_battleId);
        uint lastPlayTime = dataStorage.getLastPlayTimeByBattleId(_battleId);

        require(!battle.isCompleted, "A winner has been detected. Proceed to verify inputs");
        require((block.timestamp - lastPlayTime) < gamePhaseDetail.maxTimeForPlayerToPlay, 
            "Time to play is expired.");
        require(nextTurn == player, "Wait till next turn");

        emit Print();

        // Get the status of the position hit
        ShipPosition[] memory shipPosition = dataStorage.
            getCorrectPositionsHitByBattleIdAndPlayer(_battleId, player);
        ProofVariables memory proofVar;

        proofVar = getProofVariables(_battleId, player, opponent, _previousPositionLeaf, 
            _previousPositionProof, shipPosition);


        require(merkleProof.checkProofOrdered(proofVar), 
            "The proof and position combination indicates an invalid move");

        updatePositionIndices(_battleId, player, _attackingPositionX, _attackingPositionY, opponent);

        // Emit an event indicating that an attack has been launched
        emit AttackLaunched(_battleId, player, opponent, _attackingPositionX, _attackingPositionY);

        checkForWinner(_battleId, player, opponent, shipPosition);

        return true;
    }

    function getProofVariables(uint _battleId, address player, address opponent, 
    bytes32 _previousPositionLeaf, bytes memory _previousPositionProof, 
    ShipPosition memory _shipPosition) internal returns (ProofVariables memory) {
        uint8[2] memory previousPositionIndex = dataStorage.
            getLastPositionsAttackedByBattleIdAndPlayer(_battleId, opponent);
        bytes32 root = dataStorage.getMerkleTreeRootByBattleIdAndPlayer(_battleId, player);
        uint256 index = (previousPositionIndex[1] * dataStorage.getGridDimensionN()) + 
            previousPositionIndex[0] + 1;

        // Emit an event containing more details about the last shot fired
        emit ConfirmShotStatus(_battleId, player, opponent, 
            previousPositionIndex, _shipPosition);
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
        dataStorage.setPositionsAttackedByBattleIdAndPlayer(_battleId, player, 
            _attackingPositionX, _attackingPositionY);
        dataStorage.setTurnByBattleId(_battleId, opponent);
        dataStorage.setPositionsAttackedByBattleIdAndPlayer(_battleId, player, 
            _attackingPositionX, _attackingPositionY);
    }*/
    
    /*function getPlayersEncryptedPositions(uint _battleId) public view returns (string memory){
        //Get the ship positions for the battle
        return dataStorage.getEncryptedMerkleTreeByBattleIdAndPlayer(_battleId, msg.sender);
    }*/
  
 }