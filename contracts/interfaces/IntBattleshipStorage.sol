// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
pragma abicoder v2;

import "../libraries/IntBattleshipStruct.sol";

interface IntBattleshipStorage {
    
    // Battle related functions

    function getBattle(uint _battleId) external view returns (IntBattleshipStruct.BattleModel memory);
    function updateBattleById(uint256 _battleId, IntBattleshipStruct.BattleModel memory _battle, 
        IntBattleshipStruct.GamePhase _gamePhase) external returns (bool);
    function createNewGameId() external returns (uint256);
    
    // Game phase and lobby related functions
    
    function getGamePhaseDetails(IntBattleshipStruct.GamePhase _gamePhase) 
        external view returns (IntBattleshipStruct.GamePhaseDetail memory);
    function setGamePhaseDetails(IntBattleshipStruct.GamePhase _gamePhase, 
        IntBattleshipStruct.GamePhaseDetail memory _detail) external returns (bool);
    function getLobbyByAddress(address _player) 
        external view returns (IntBattleshipStruct.LobbyModel memory);
    function setLobbyByAddress(address _player, IntBattleshipStruct.LobbyModel memory _lobby) 
        external;
    
    // Merkle Tree
    
    function getMerkleTreeRootByBattleIdAndPlayer(uint256 _battleId, 
        address _playerAddress) external view returns (bytes32);
    function setMerkleTreeRootByBattleIdAndPlayer(uint256 _battleId, 
        address _playerAddress, bytes32 _merkleTreeRoot) external returns (bool);
    
    // Position attack related functions
    
    function getTurnByBattleId(uint256 _battleId) external view returns (address);
    function setTurnByBattleId(uint256 _battleId, address _turn) 
        external returns (bool);
    
    function getLastPlayTimeByBattleId(uint256 _battleId) 
        external view returns (uint256);
    function setLastPlayTimeFirstTime(uint256 _battleId, uint256 _playTime) 
        external returns (bool);
    function setLastPlayTimeByBattleId(uint256 _battleId, uint256 _playTime) 
        external returns (bool);

    function getPositionsAttackedLength(uint256 _battleId, address _player) 
        external view returns (uint256);
    function getAllPositionsAttacked(uint256 _battleId, address _player)
        external view returns (uint8[2][] memory);
    function getLastPositionsAttackedByBattleIdAndPlayer(uint256 _battleId, 
        address _player) external view returns (uint8[2] memory);
    function setPositionsAttackedByBattleIdAndPlayer(uint256 _battleId, 
        address _player, uint8 attackingPositionX, uint8 attackingPositionY, 
        address _currentPlayer) external returns (bool);
    function getSender() external view returns(address);
    
    // Correct positions hit related functions

    function getCorrectPositionsHitByBattleIdAndPlayer(uint256 _battleId, 
        address _player) external view returns (IntBattleshipStruct.ShipPosition[] memory);
    function setCorrectPositionsHitByBattleIdAndPlayer(uint256 _battleId, 
        address _player, IntBattleshipStruct.ShipPosition memory _shipPosition) 
        external returns (bool);
    

    function getNumShips() external view returns (uint8);
    function getSumOfShipSize() external view returns (uint8);
    function getGridDimensionN() external view returns (uint8);
    function setGridDimensionN(uint8 _newValue) external;

    function msgSender() external view returns(address _sender);

    function getShipLenghtFromIndex(uint8 _index) external view returns (uint8);

    // get a single ship position knowing the axis
    function getShipPositionByAxis(address _player,  uint8 _axisX, uint8 _axisY) 
        external view returns (IntBattleshipStruct.ShipPosition memory);

    // return true if a ship has been hit, false otherwise
    function isHit(address _player, uint8 _axisX, uint8 _axisY) 
        external view returns (bool);

    // get a single Merkle Tree leaf inside the struct PlayerModel
    function getMerkleTreeLeaf(address _address, uint8 _axisX, uint8 _axisY) 
    external view returns (bytes32);

    // get all Merkle Tree leaves inside the struct PlayerModel
    function getMerkleTreeLeaves(address _address) 
        external view returns (bytes32[][] memory);

    // set all the ship
    function setShipPositions(uint8[] memory _shipLengths, uint8[] memory _axisXs,
        uint8[] memory _axisYs, IntBattleshipStruct.ShipDirection[] memory _directions, 
        address _player) external;

    function getMerkleTreeProof(address _player) external view returns (bytes32[] memory);

    function getMerkleTreeProofLength(address _player) external view returns (uint256);

    function getMerkleRoot(address _player) external view returns (bytes32);

    // create a Merkle root from the Merkle tree leaves
    function calculateMerkleRoot(bytes32[][] memory _leaves,
        address _player) external returns (bytes32);

    function generateProof(address _player, uint8 axisY, uint8 axisX, uint8 dim) 
        external returns (bytes32[] memory);

    function verifyProof(bytes32[] memory _proof, address _player, uint8 axisY, 
        uint8 axisX, uint8 dim) external returns (bool);

}
