// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma experimental ABIEncoderV2;

import "./interfaces/IntBattleshipStruct.sol";
import "./interfaces/IntBattleshipLogic.sol";

contract BattleshipStorage is IntBattleshipStruct {
    uint8 constant private TOTAL_TILES_REQUIRED = 17;
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

    mapping(ShipType => uint8) private shipSizes;
    mapping(uint256 => BattleModel) private battles;
    mapping(address => PlayerModel) private players;
    mapping(uint256 => mapping(address => mapping(uint256 => bytes32))) private revealedPositions;
    mapping(uint256 => mapping(address => uint8[])) private positionsAttacked;
    mapping(uint256 => mapping(address => string)) private encryptedMerkleTree;
    mapping(uint256 => mapping(address => bytes32)) private merkleTreeRoot;
    mapping(uint256 => mapping(address => uint8)) private lastFiredPositionIndex;
    mapping(uint256 => address) private turn;
    mapping(uint256 => uint256) private lastPlayTime;
    mapping(uint256 => mapping(address => ShipPosition[])) correctPositionsHit;
    mapping(uint256 => mapping(address => VerificationStatus)) private battleVerification;
    mapping(uint256 => mapping(address => string)) private revealedLeafs;
    mapping(GameMode => LobbyModel) private lobbyMap;
    mapping(GameMode => GameModeDetail) private gameModeMapping;

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
        shipSizes[ShipType.Destroyer] = 2;
        shipSizes[ShipType.Submarine] = 3;
        shipSizes[ShipType.Cruiser] = 3;
        shipSizes[ShipType.Battleship] = 4;
        shipSizes[ShipType.Carrier] = 5;
        maxNumberOfMissiles = 5;
        isTest = _isTest;
        gameLogic = IntBattleshipLogic(_gameLogic);

        gameModeMapping[GameMode.Regular] = GameModeDetail(minStakingAmount, GameMode.Regular, minTimeRequiredForPlayerToRespond);
        gameModeMapping[GameMode.Intermediate] = GameModeDetail(minStakingAmount, GameMode.Regular, minTimeRequiredForPlayerToRespond);
        gameModeMapping[GameMode.Professional] = GameModeDetail(minStakingAmount, GameMode.Regular, minTimeRequiredForPlayerToRespond);
    }

    // Battle related functions

    function getBattle(uint256 _battleId) public view returns (BattleModel memory) {
        return battles[_battleId];
    }

    function updateBattle(uint256 _battleId, BattleModel memory _battle) external onlyAuthorized returns (bool) {
        _battle.updatedAt = block.timestamp;
        if (_battle.createdAt == 0) {
            _battle.createdAt = block.timestamp;
        }
        battles[_battleId] = _battle;
        return true;
    }

    function getNewGameId() external returns (uint256) {
        gameId++;
        return gameId;
    }

    function setBattleshipContractAddress(address _address) onlyOwner external returns (bool) {
        battleShipContractAddress = _address;
        return true;
    }

    // Player related functions

    function getPlayer(address _address) public view returns (PlayerModel memory) {
        return players[_address];
    }

    function getContractOwner() public view returns (address) {
        return owner;
    }

    function updatePlayer(address _player, PlayerModel memory _playerModel) onlyAuthorized external returns (bool) {
        _playerModel.updatedAt = block.timestamp;
        if (_playerModel.createdAt == 0) {
            _playerModel.createdAt = block.timestamp;
        }
        players[_player] = _playerModel;
        return true;
    }

    // Game mode and lobby related functions

    function setGameModeDetails(GameMode _gameMode, GameModeDetail memory _detail) external returns (bool) {
        gameModeMapping[_gameMode] = _detail;
        return true;
    }

    function getGameModeDetails(GameMode _gameMode) external view returns (GameModeDetail memory) {
        return gameModeMapping[_gameMode];
    }

    function getLobby(GameMode _gameMode) external view returns (LobbyModel memory) {
        return lobbyMap[_gameMode];
    }

    function updateLobby(GameMode _gameMode, LobbyModel memory _lobbyModel) external returns (bool) {
        lobbyMap[_gameMode] = _lobbyModel;
        return true;
    }

    // Merkle Tree related functions

    function getEncryptedMerkleTree(uint256 _battleId, address _player) external view returns (string memory) {
        return encryptedMerkleTree[_battleId][_player];
    }

    function getRevealedPositionValue(uint256 _battleId, address _revealingPlayer, uint256 _position) external view returns (bytes32) {
        return revealedPositions[_battleId][_revealingPlayer][_position];
    }

    function setEncryptedMerkleTree(uint256 _battleId, address _player, string memory _encryptedMerkleTree) external returns (bool) {
        encryptedMerkleTree[_battleId][_player] = _encryptedMerkleTree;
        return true;
    }

    function setRevealedPositionValue(uint256 _battleId, address _revealingPlayer, uint256 _position, bytes32 _value) external returns (bool) {
        revealedPositions[_battleId][_revealingPlayer][_position] = _value;
        return true;
    }

    function getMerkleTreeRootByBattleIdAndPlayer(uint256 _battleId, address _player) external view returns (bytes32) {
        return merkleTreeRoot[_battleId][_player];
    }

    function setMerkleTreeRootByBattleIdAndPlayer(uint256 _battleId, address _player, bytes32 _root) external returns (bool) {
        merkleTreeRoot[_battleId][_player] = _root;
        return true;
    }

    // Position attack related functions

    function getLastFiredPositionIndexByBattleIdAndPlayer(uint256 _battleId, address _player) external view returns (uint8) {
        return lastFiredPositionIndex[_battleId][_player];
    }

    function setLastFiredPositionIndexByBattleIdAndPlayer(uint256 _battleId, address _player, uint8 _index) external returns (bool) {
        lastFiredPositionIndex[_battleId][_player] = _index;
        return true;
    }

    function getPositionsAttackedByBattleIdAndPlayer(uint256 _battleId, address _player) external view returns (uint8[] memory) {
        return positionsAttacked[_battleId][_player];
    }

    function setPositionsAttackedByBattleIdAndPlayer(uint256 _battleId, address _player, uint8[] memory _positions) external returns (bool) {
        positionsAttacked[_battleId][_player] = _positions;
        return true;
    }

    // Correct positions hit related functions

    function getCorrectPositionsHitByBattleIdAndPlayer(uint256 _battleId, address _player) external view returns (ShipPosition[] memory) {
        return correctPositionsHit[_battleId][_player];
    }

    function setCorrectPositionsHitByBattleIdAndPlayer(uint256 _battleId, address _player, ShipPosition[] memory _positions) external returns (bool) {
        correctPositionsHit[_battleId][_player] = _positions;
        return true;
    }

    // Battle verification related functions

    function getBattleVerification(uint256 _battleId, address _player) external view returns (VerificationStatus) {
        return battleVerification[_battleId][_player];
    }

    function setBattleVerification(uint256 _battleId, address _player, VerificationStatus _verificationStatus) external returns (bool) {
        battleVerification[_battleId][_player] = _verificationStatus;
        return true;
    }

    // Revealed leafs related functions

    function getRevealedLeafsByBattleIdAndPlayer(uint256 _battleId, address _player) external view returns (string memory) {
        return revealedLeafs[_battleId][_player];
    }

    function setRevealedLeafsByBattleIdAndPlayer(uint256 _battleId, address _player, string memory _leafs) external returns (bool) {
        revealedLeafs[_battleId][_player] = _leafs;
        return true;
    }

    // Miscellaneous functions

    function getPlayerAddresses() external view returns (address[] memory) {
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

    function getTransactionOfficer() external view returns (address payable) {
        return transactionOfficer;
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
    }
}
