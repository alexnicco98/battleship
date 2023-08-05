// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma experimental ABIEncoderV2;

import "./interfaces/IntBattleshipStruct.sol";
import "./interfaces/IntBattleshipLogic.sol";

abstract contract BattleshipStorage is IntBattleshipStruct, IntBattleshipLogic {
    // in the next development, should be a non-fixed variable that
    // the host player chose at the moment of creation of the game
    uint8 constant private gridDimensionN = 4;
    uint256 private gameId;
    uint256 private minTimeRequiredForPlayerToRespond;
    uint256 private maxNumberOfMissiles;
    uint256 private minStakingAmount;
    uint256 private totalNumberOfPlayers;
    address[] private playerAddresses;
    address payable private owner;
    address payable private transactionOfficer;
    uint256 private rewardCommissionRate;
    uint256 private cancelCommissionRate;
    bool private isTest;

    address private battleShipContractAddress;
    IntBattleshipLogic private gameLogic;


    mapping(uint8 => uint8) private shipSizes;
    mapping(uint256 => BattleModel) private battles;
    mapping(address => PlayerModel) private players;
    mapping(uint256 => mapping(address => mapping(uint256 => bytes32))) private revealedPositions;
    mapping(uint256 => mapping(address => uint8[])) private positionsAttacked;
    mapping(uint256 => mapping(address => string)) private encryptedMerkleTree;
    mapping(uint256 => mapping(address => bytes32)) private merkleTreeRoot;
    mapping(uint256 => mapping(address => uint8[2])) private lastFiredPositionIndex;
    mapping(uint256 => address) private turn;
    mapping(uint256 => uint256) private lastPlayTime;
    mapping(uint256 => mapping(address => ShipPositionMapping[])) correctPositionsHit;
    mapping(uint256 => mapping(address => VerificationStatus)) private battleVerification;
    mapping(uint256 => mapping(address => string)) private revealedLeafs;
    mapping(GamePhase => LobbyModel) private lobbyMap;
    mapping(GamePhase => GamePhaseDetail) private gamePhaseMapping;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can execute this transaction");
        _;
    }

    modifier onlyAuthorized() {
        address sender = msg.sender;
        bool isBattleShipContract = sender == battleShipContractAddress;
        require(isBattleShipContract || isTest, "Unauthorized access");
        _;
    }

    constructor(bool _isTest, address _gameLogic) {
        gameId = 0;
        owner = payable(address(msg.sender));
        for (uint8 i = 0; i < gridDimensionN - 1; i++) {
            shipSizes[i] = i + 1;
        }
        // TODO: change to be the number of cels inside the matrix
        maxNumberOfMissiles = 16;
        isTest = _isTest;
        gameLogic = IntBattleshipLogic(_gameLogic);

        gamePhaseMapping[GamePhase.Placement] = GamePhaseDetail(minStakingAmount, GamePhase.Placement, minTimeRequiredForPlayerToRespond);
        gamePhaseMapping[GamePhase.Shooting] = GamePhaseDetail(minStakingAmount, GamePhase.Placement, minTimeRequiredForPlayerToRespond);
        gamePhaseMapping[GamePhase.Gameover] = GamePhaseDetail(minStakingAmount, GamePhase.Placement, minTimeRequiredForPlayerToRespond);
    }

    // Battle related functions

    function getBattle(uint256 _battleId) public view returns (BattleModel memory) {
        return battles[_battleId];
    }

    function updateBattleById(uint256 _battleId, BattleModel memory _battle) external onlyAuthorized returns (bool) {
        _battle.updatedAt = block.timestamp;
        if (_battle.createdAt == 0) {
            _battle.createdAt = block.timestamp;
        }
        battles[_battleId] = _battle;
        return true;
    }

    function createNewGameId() external returns (uint256) {
        gameId++;
        return gameId;
    }

    // Player related functions

    function getPlayerByAddress(address _address) public view returns (PlayerModel memory) {
        return players[_address];
    }

    function getContractOwner() public view returns (address) {
        return owner;
    }

    function setBattleshipContractAddress(address _address) onlyOwner external returns (bool) {
        battleShipContractAddress = _address;
        return true;
    }

    /*function updatePlayerByAddress(address _player, PlayerModel memory _playerModel) onlyAuthorized external returns (bool) {
        _playerModel.updatedAt = block.timestamp;
        if (_playerModel.createdAt == 0) {
            _playerModel.createdAt = block.timestamp;
        }
        players[_player] = _playerModel;
        return true;
    }*/

    // Game mode and lobby related functions

    function getGamePhaseDetails(GamePhase _gamePhase) external view returns (GamePhaseDetail memory) {
        return gamePhaseMapping[_gamePhase];
    }

    /*function setGamePhaseDetails(GamePhase _gamePhase, GamePhaseDetail memory _detail) external returns (bool) {
        gamePhaseMapping[_gamePhase] = _detail;
        return true;
    }*/

    function getLobbyByGamePhase(GamePhase _gamePhase) external view returns (LobbyModel memory) {
        return lobbyMap[_gamePhase];
    }

    function setLobbyByGamePhase(GamePhase _gamePhase, LobbyModel memory _lobbyModel) external returns (bool) {
        lobbyMap[_gamePhase] = _lobbyModel;
        return true;
    }

    // Merkle Tree related functions

    function getEncryptedMerkleTreeByBattleIdAndPlayer(uint256 _battleId, address _player) external view returns (string memory) {
        return encryptedMerkleTree[_battleId][_player];
    }

    function setEncryptedMerkleTreeByBattleIdAndPlayer(uint256 _battleId, address _player, string memory _encryptedMerkleTree) external returns (bool) {
        encryptedMerkleTree[_battleId][_player] = _encryptedMerkleTree;
        return true;
    }

    /*function getRevealedPositionValueByBattleIdAndPlayer(uint256 _battleId, address _revealingPlayer, uint256 _position) external view returns (bytes32) {
        return revealedPositions[_battleId][_revealingPlayer][_position];
    }

    function setRevealedPositionByBattleIdAndPlayer(uint256 _battleId, address _revealingPlayer, uint256 _position, bytes32 _value) external returns (bool) {
        revealedPositions[_battleId][_revealingPlayer][_position] = _value;
        return true;
    }*/

    function getMerkleTreeRootByBattleIdAndPlayer(uint256 _battleId, address _player) external view returns (bytes32) {
        return merkleTreeRoot[_battleId][_player];
    }

    function setMerkleTreeRootByBattleIdAndPlayer(uint256 _battleId, address _player, bytes32 _root) external returns (bool) {
        merkleTreeRoot[_battleId][_player] = _root;
        return true;
    }

    // Position attack related functions

    function getLastFiredPositionIndexByBattleIdAndPlayer(uint256 _battleId, address _player) external view returns (uint8[2] memory) {
        return lastFiredPositionIndex[_battleId][_player];
    }

    function setLastFiredPositionIndexByBattleIdAndPlayer(uint256 _battleId, address _player, uint8 _attackingPositionX, uint8 _attackingPositionY) external returns (bool) {
        lastFiredPositionIndex[_battleId][_player] = [_attackingPositionX, _attackingPositionY];
        return true;
    }

    function getLastPlayTimeByBattleId (uint _battleId) external view returns (uint)
    {
        return lastPlayTime[_battleId];
    }
    
    /*function setLastPlayTimeByBattleId(uint _battleId, uint _playTime) external returns (bool)
    {
        lastPlayTime[_battleId] = _playTime;
        return true;
    }*/

    function getPositionsAttackedByBattleIdAndPlayer(uint256 _battleId, address _player) external view returns (uint8[] memory) {
        return positionsAttacked[_battleId][_player];
    }

    // check the correctness
    function setPositionsAttackedByBattleIdAndPlayer(uint256 _battleId, address _player, uint8 attackingPositionX, uint8 attackingPositionY) external returns (bool) {
        positionsAttacked[_battleId][_player] = [attackingPositionX, attackingPositionY];
        return true;
    }

    // Correct positions hit related functions

    function getCorrectPositionsHitByBattleIdAndPlayer(uint256 _battleId, address _player) external view returns (ShipPositionMapping[] memory) {
        return correctPositionsHit[_battleId][_player];
    }

    function setCorrectPositionsHitByBattleIdAndPlayer(uint256 _battleId, address _player, ShipPositionMapping[] memory _positions) external returns (bool) {
        correctPositionsHit[_battleId][_player] = _positions;
        return true;
    }

    // Battle verification related functions

    /*function getBattleVerification(uint256 _battleId, address _player) external view returns (VerificationStatus) {
        return battleVerification[_battleId][_player];
    }

    function setBattleVerification(uint256 _battleId, address _player, VerificationStatus _verificationStatus) external returns (bool) {
        battleVerification[_battleId][_player] = _verificationStatus;
        return true;
    }*/

    // Revealed leafs related functions

    function getRevealedLeafsByBattleIdAndPlayer(uint256 _battleId, address _player) external view returns (string memory) {
        return revealedLeafs[_battleId][_player];
    }

    function setRevealedLeafsByBattleIdAndPlayer(uint256 _battleId, address _player, string memory _leafs) external returns (bool) {
        revealedLeafs[_battleId][_player] = _leafs;
        return true;
    }

    // Miscellaneous functions

    function getTurnByBattleId(uint _battleId) external view returns(address){
        return turn[_battleId];
    }
    
    function setTurnByBattleId (uint _battleId, address _turn) external returns (bool){
        turn[_battleId]  = _turn;
        return true;
    }

    function getTransactionOfficer() external view returns (address payable) {
        return transactionOfficer;
    }

    
}

/*function getPlayerAddresses() external view returns (address[] memory) {
        return playerAddresses;
    }

    function setPlayerAddresses(address[] memory _playerAddresses) external onlyOwner returns (bool) {
        playerAddresses = _playerAddresses;
        return true;
    }

    function addPlayerAddress(address _playerAddress) external onlyOwner returns (bool) {
        playerAddresses.push(_playerAddress);
        return true;
    }

    function removePlayerAddress(address _playerAddress) external onlyOwner returns (bool) {
        uint256 len = playerAddresses.length;
        for (uint256 i = 0; i < len; i++) {
            if (playerAddresses[i] == _playerAddress) {
                playerAddresses[i] = playerAddresses[len - 1];
                playerAddresses.pop();
                return true;
            }
        }
        return false;
    }

    function updateOwner(address payable _owner) external onlyOwner returns (bool) {
        owner = _owner;
        return true;
    }

    function getGameId() external view returns (uint256) {
        return gameId;
    }

    function setGameId(uint256 _gameId) external onlyOwner returns (bool) {
        gameId = _gameId;
        return true;
    }

    function getMinTimeRequiredForPlayerToRespond() external view returns (uint256) {
        return minTimeRequiredForPlayerToRespond;
    }

    function setMinTimeRequiredForPlayerToRespond(uint256 _minTime) external onlyOwner returns (bool) {
        minTimeRequiredForPlayerToRespond = _minTime;
        return true;
    }

    function getMaxNumberOfMissiles() external view returns (uint256) {
        return maxNumberOfMissiles;
    }

    function setMaxNumberOfMissiles(uint256 _maxMissiles) external onlyOwner returns (bool) {
        maxNumberOfMissiles = _maxMissiles;
        return true;
    }

    function getMinStakingAmount() external view returns (uint256) {
        return minStakingAmount;
    }

    function setMinStakingAmount(uint256 _minStakingAmount) external onlyOwner returns (bool) {
        minStakingAmount = _minStakingAmount;
        return true;
    }

    function getTotalNumberOfPlayers() external view returns (uint256) {
        return totalNumberOfPlayers;
    }

    function setTotalNumberOfPlayers(uint256 _totalPlayers) external onlyOwner returns (bool) {
        totalNumberOfPlayers = _totalPlayers;
        return true;
    }

    function setTransactionOfficer(address payable _transactionOfficer) external onlyOwner returns (bool) {
        transactionOfficer = _transactionOfficer;
        return true;
    }

    function getRewardCommissionRate() external view returns (uint256) {
        return rewardCommissionRate;
    }

    function setRewardCommissionRate(uint256 _commissionRate) external onlyOwner returns (bool) {
        rewardCommissionRate = _commissionRate;
        return true;
    }

    function getCancelCommissionRate() external view returns (uint256) {
        return cancelCommissionRate;
    }

    function setCancelCommissionRate(uint256 _commissionRate) external onlyOwner returns (bool) {
        cancelCommissionRate = _commissionRate;
        return true;
    }

    function setIsTest(bool _isTest) external onlyOwner returns (bool) {
        isTest = _isTest;
        return true;
    }*/