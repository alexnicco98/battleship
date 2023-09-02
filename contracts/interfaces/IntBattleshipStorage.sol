// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
pragma abicoder v2;

import "./IntBattleshipStruct.sol";
//import "./IntBattleshipLogic.sol";

interface IntBattleshipStorage is IntBattleshipStruct {
    
    // Battle related functions
    function getBattle(uint _battleId) external view returns (BattleModel memory);
    function updateBattleById(uint256 _battleId, BattleModel memory _battle, 
        GamePhase _gamePhase) external returns (bool);
    function createNewGameId() external returns (uint256);
    
    // Game phase and lobby related functions
    
    //function setGameLogicAddress(address _gameLogicAddress) 
        //external returns (bool);
    function getGamePhaseDetails(GamePhase _gamePhase) 
        external view returns (GamePhaseDetail memory);
    function setGamePhaseDetails(GamePhase _gamePhase, 
        GamePhaseDetail memory _detail) external returns (bool);
    function getLobbyByAddress(address _player) 
        external view returns (LobbyModel memory);
    function setLobbyByAddress(address _player, LobbyModel memory _lobby) 
        external returns (bool);
    
    // Player related functions
    function getPlayerByAddress(address _address) external view returns (PlayerModel memory);
    function getContractOwner() external view returns (address);
    function setBattleshipContractAddress(address _address) external returns (bool);
    //function updatePlayerByAddress(address _address, PlayerModel memory _player) 
    //    external returns (bool);
    
    // Merkle Tree
    function encryptMerkleTree(bytes32 _merkleTree) external pure returns (bytes32);
    
    //function getRevealedPositionValueByBattleIdAndPlayer(uint256 _battleId, 
    //    address _revealingPlayer, uint8 _position) external view returns (bytes32);
    //function setRevealedPositionByBattleIdAndPlayer(uint256 _battleId, address _player, 
    //    uint8 _position, bytes32 _revealedPosition) external returns (bool);
    
    function getMerkleTreeRootByBattleIdAndPlayer(uint256 _battleId, 
        address _playerAddress) external view returns (bytes32);
    function setMerkleTreeRootByBattleIdAndPlayer(uint256 _battleId, 
        address _playerAddress, bytes32 _merkleTreeRoot) external returns (bool);
    
    // Position attack related functions

    /*function getLastFiredPositionIndexByBattleIdAndPlayer(uint256 _battleId, 
        address _player) external view returns (uint8[2] memory);
    function setLastFiredPositionIndexByBattleIdAndPlayer(uint256 _battleId, 
        address _player, uint8 _attackingPositionX, uint8 _attackingPositionY) 
        external returns (bool);*/
    
    function getTurnByBattleId(uint256 _battleId) external view returns (address);
    function setTurnByBattleId(uint256 _battleId, address _turn) 
        external returns (bool);
    
    function getLastPlayTimeByBattleId(uint256 _battleId) 
        external view returns (uint256);
    function setLastPlayTimeByBattleId(uint256 _battleId, uint256 _playTime) 
        external returns (bool);

    function getPositionsAttackedLength(uint256 _battleId, address _player) 
        external view returns (uint256);
    function getLastPositionsAttackedByBattleIdAndPlayer(uint256 _battleId, 
        address _player) external view returns (uint8[2] memory);
    function setPositionsAttackedByBattleIdAndPlayer(uint256 _battleId, 
        address _player, uint8 attackingPositionX, uint8 attackingPositionY) 
        external returns (bool);
    
    // Correct positions hit related functions

    function getCorrectPositionsHitByBattleIdAndPlayer(uint256 _battleId, 
        address _player) external view returns (ShipPosition[] memory);
    function setCorrectPositionsHitByBattleIdAndPlayer(uint256 _battleId, 
        address _player, ShipPosition memory _shipPosition) 
        external returns (bool);
    
    // Battle verification related functions

    //function getBattleVerification(uint256 _battleId, address _player) 
    //    external view returns (VerificationStatus);
    //function setBattleVerification(uint256 _battleId, address _player, 
    //    VerificationStatus _status) external returns (bool);
    
    function getTransactionOfficer() external view returns (address);
    //function setTransactionOfficer(address payable _transactionOfficer) 
        //external returns (bool);
    
    // Revealed leafs and proofs related functions

    function getRevealedLeavesByBattleIdAndPlayer(uint256 _battleId, 
        address _playerAddress) external view returns (bytes32);
    function setRevealedLeavesByBattleIdAndPlayer(uint256 _battleId, 
        address _playerAddress, bytes32 _revealedLeaves) external returns (bool);
    function getProofByIndexAndPlayer(uint256 _index, address _player) 
        external view returns (bytes32);
    function setProofByIndexAndPlayer(uint256 _index, address _player, 
        bytes32 _proof) external returns (bool);
    //function getLeafByIndexAndPlayer(uint256 _indexX, uint256 _indexY, 
    //    address _player) external view returns (bytes32);
    //function setLeafByIndexAndPlayer(uint256 _indexX, uint256 _indexY, 
    //    address _player, bytes32 _leaf) external returns (bool);

    function getNumShips() external view returns (uint8);
    function getSumOfShipSize() external view returns (uint8);
    function getGridDimensionN() external view returns (uint8);
    function setGridDimensionN(uint8 _newValue) external;

    function msgSender() external view returns(address _sender);

    function getShipLenghtFromIndex(uint8 _index) external view returns (uint8);

    /*function getShipInxesFromShipLength(uint8 shipLenght) 
    external view returns (uint8[] memory);*/

    //function getSlice(uint256 begin, uint256 end, string memory text) 
    //    external view returns (string memory);

    // get a single ship position inside the struct PlayerModel
    function getShipPosition(uint8 _positionKey) 
        external view returns (ShipPosition memory);

    // get a single ship position knowing the axis
    function getShipPositionByAxis(address _player,  uint8 _axisX, uint8 _axisY) 
        external view returns (ShipPosition memory);

    // get a single Merkle Tree leaf inside the struct PlayerModel
    function getMerkleTreeLeaf(address _address, uint8 _axisX, uint8 _axisY) 
    external view returns (bytes32);

    // get all Merkle Tree leaves inside the struct PlayerModel
    function getMerkleTreeLeaves(address _address) 
        external view returns (bytes32[][] memory);

    // set all the ship
    function setShipPositions(uint8[] memory _shipLengths, uint8[] memory _axisXs,
        uint8[] memory _axisYs, ShipDirection[] memory _directions, 
        address _player) external;

    // create a Merkle tree leaves from the ship positions
    //function createMerkleTreeLeaf(uint256 _state) external view returns (bytes32);

    function getMerkleTreeProof(address _player) external view returns (bytes32[] memory);

    function getMerkleTreeProofLength(address _player) external view returns (uint256);

    function getMerkleRoot(address _player) external view returns (bytes32);

    // create a Merkle root from the Merkle tree leaves
    function calculateMerkleRoot(bytes32[][] memory _leaves,
    address _player) external returns (bytes32);

    function generateSingleLeafProof(bytes32[][] memory _leaves, bytes32 _leaf, 
    bytes32 _root, uint8 _leafIndexY, uint8 _leafIndexX) external pure returns (bytes32);

    function generateProof(address _player, uint8 axisY, uint8 axisX) 
    external returns (bytes32[] memory);

    function verifyProof(bytes32[] memory _proof, address _player, uint8 axisY, uint8 axisX) 
    external returns (bool);

    function verifyAdversaryLeaf(uint256 _battleId, address _adversary, bytes32 _leaf, 
    bytes32 _root) external view returns (bool);

    /*function checkProofOrdered(bytes memory proof, bytes32 root, 
    string memory hash, uint256 index) external returns (bool);
    
    function checkProofsOrdered(bytes[] memory proofs, bytes32 root, 
    string memory leafs) external returns (bool);*/

    /*function checkProof(bytes32[] memory proof, bytes32 root, bytes32 leaf) 
    external pure returns (bool);*/

    //function getOrderedPositionsAndAxis(string memory positions) 
    //    external pure returns (uint8[] memory, AxisType[5] memory);

    /*function checkEqualArray(uint8[] memory arr1, uint8[] memory arr2) 
        external pure returns (bool);

    function getSliceOfBytesArray(bytes memory bytesArray, uint16 indexStart, 
        uint16 indexStop) external pure returns (bytes memory);
    */
}
