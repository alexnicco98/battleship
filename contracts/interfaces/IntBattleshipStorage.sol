// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma experimental ABIEncoderV2;

import "./IntBattleshipStruct.sol";

interface IntBattleshipStorage is IntBattleshipStruct {
    
    // Battle related functions
    function getBattle(uint _battleId) external view returns (BattleModel memory);
    function updateBattleById(uint256 _battleId, BattleModel memory _battle) external returns (bool);
    function createNewGameId() external returns (uint256);
    
    // Game phase and lobby related functions
    
    //function setGameLogicAddress(address _gameLogicAddress) external returns (bool);
    function getGamePhaseDetails(GamePhase _gamePhase) external view returns (GamePhaseDetail memory);
    //function setGamePhaseDetails(GamePhase _gamePhase, GamePhaseDetail memory _detail) external returns (bool);
    function getLobbyByGamePhase(GamePhase _gamePhase) external view returns (LobbyModel memory);
    function setLobbyByGamePhase(GamePhase _gamePhase, LobbyModel memory _lobby) external returns (bool);
    
    // Player related functions
    function getPlayerByAddress(address _address) external view returns (PlayerModel memory);
    function getContractOwner() external view returns (address);
    function setBattleshipContractAddress(address _address) external returns (bool);
    //function updatePlayerByAddress(address _address, PlayerModel memory _player) external returns (bool);
    
    // Merkle Tree
    function getEncryptedMerkleTreeByBattleIdAndPlayer(uint256 _battleId, address _player) external view returns (string memory);
    function setEncryptedMerkleTreeByBattleIdAndPlayer(uint256 _battleId, address _player, string memory _encryptedMerkleTree) external returns (bool);
    
    //function getRevealedPositionValueByBattleIdAndPlayer(uint256 _battleId, address _revealingPlayer, uint8 _position) external view returns (bytes32);
    //function setRevealedPositionByBattleIdAndPlayer(uint256 _battleId, address _player, uint8 _position, bytes32 _revealedPosition) external returns (bool);
    
    function getMerkleTreeRootByBattleIdAndPlayer(uint256 _battleId, address _playerAddress) external view returns (bytes32);
    function setMerkleTreeRootByBattleIdAndPlayer(uint256 _battleId, address _playerAddress, bytes32 _merkleTreeRoot) external returns (bool);
    
    // Position attack related functions

    function getLastFiredPositionIndexByBattleIdAndPlayer(uint256 _battleId, address _player) external view returns (uint8);
    function setLastFiredPositionIndexByBattleIdAndPlayer(uint256 _battleId, address _player, uint8 _lastFiredPosition) external returns (bool);
    
    function getTurnByBattleId(uint256 _battleId) external view returns (address);
    function setTurnByBattleId(uint256 _battleId, address _turn) external returns (bool);
    
    function getLastPlayTimeByBattleId(uint256 _battleId) external view returns (uint256);
    function setLastPlayTimeByBattleId(uint256 _battleId, uint256 _playTime) external returns (bool);
    
    function getPositionsAttackedByBattleIdAndPlayer(uint256 _battleId, address _player) external view returns (uint8[] memory);
    function setPositionsAttackedByBattleIdAndPlayer(uint256 _battleId, address _player, uint8 _position) external returns (bool);
    
    // Correct positions hit related functions

    function getCorrectPositionsHitByBattleIdAndPlayer(uint256 _battleId, address _player) external view returns (ShipPosition[] memory);
    function setCorrectPositionsHitByBattleIdAndPlayer(uint256 _battleId, address _player, ShipPosition memory _shipPosition) external returns (bool);
    
    // Battle verification related functions

    //function getBattleVerification(uint256 _battleId, address _player) external view returns (VerificationStatus);
    //function setBattleVerification(uint256 _battleId, address _player, VerificationStatus _status) external returns (bool);
    
    function getTransactionOfficer() external view returns (address);
    //function setTransactionOfficer(address payable _transactionOfficer) external returns (bool);
    
    // Revealed leafs related functions

    function getRevealedLeafsByBattleIdAndPlayer(uint256 _battleId, address _playerAddress) external view returns (string memory);
    function setRevealedLeafsByBattleIdAndPlayer(uint256 _battleId, address _playerAddress, string memory _revealedLeafs) external returns (bool);
}
