// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
pragma abicoder v2;

import "./interfaces/IntBattleshipStruct.sol";
//import "./interfaces/IntBattleshipLogic.sol";

contract BattleshipStorage is IntBattleshipStruct {
    
    // in the next development, should be a non-fixed variable that
    // the host player chose at the moment of creation of the game
    uint8 private gridDimensionN = 4;
    uint8 private numShips = 2;
    uint256 private gameId;
    uint256 private minTimeRequiredForPlayerToRespond = 3 minutes;
    uint256 private maxNumberOfMissiles;
    uint256 private minStakingAmount = uint(0.0001 ether);
    uint256 private totalNumberOfPlayers;
    address payable private owner;
    address payable private transactionOfficer;
    uint256 private rewardCommissionRate;
    uint256 private cancelCommissionRate;
    bool private isTest;
    //ShipPosition[] public shipPositionMapping;
    uint8 public sumOfShipSizes = 0;
    uint8 private gridSquare;

    address private battleShipContractAddress;
    //IntBattleshipLogic private gameLogic;

    mapping(uint256 => BattleModel) private battles;
    mapping(address => PlayerModel) private players;
    //mapping(uint256 => mapping(address => mapping(uint256 => bytes32))) private revealedPositions;
    mapping(uint256 => mapping(address => uint8[])) private positionsAttacked;
    mapping(uint256 => mapping(address => string)) private encryptedMerkleTree;
    mapping(uint256 => mapping(address => bytes32)) private merkleTreeRoot;
    mapping(uint256 => mapping(address => uint8[2])) private lastFiredPositionIndex;
    mapping(uint256 => address) private turn;
    mapping(uint256 => uint256) private lastPlayTime;
    mapping(uint256 => mapping(address => ShipPosition[])) correctPositionsHit;
    //mapping(uint256 => mapping(address => VerificationStatus)) private battleVerification;
    mapping(uint256 => mapping(address => uint8)) private revealedLeafs;
    mapping(address => LobbyModel) private lobbyMap;
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

    constructor(bool _isTest) {
        gameId = 0;
        // TODO: change to be the number of cels inside the matrix
        maxNumberOfMissiles = gridDimensionN * gridDimensionN;
        isTest = _isTest;
        //gameLogic = IntBattleshipLogic(_gameLogic);

        gamePhaseMapping[GamePhase.Placement] = GamePhaseDetail(minStakingAmount, GamePhase.Placement, minTimeRequiredForPlayerToRespond);
        gamePhaseMapping[GamePhase.Shooting] = GamePhaseDetail(minStakingAmount, GamePhase.Shooting, minTimeRequiredForPlayerToRespond);
        gamePhaseMapping[GamePhase.Gameover] = GamePhaseDetail(minStakingAmount, GamePhase.Gameover, minTimeRequiredForPlayerToRespond);
        initializeShipPositionMapping();
        gridSquare = gridDimensionN * gridDimensionN;
    }


    function initializeShipPositionMapping() private {
        uint8 shipSizes;
        uint8 axisX;
        uint8 axisY;
        for (uint8 i = 0; i < numShips; i++) {
            shipSizes = i + 1;
            sumOfShipSizes += shipSizes;
            (axisX, axisY) = (0,0);
            players[owner].shipPositions.push(ShipPosition({
                shipLength: shipSizes,
                direction: ShipDirection.None,
                axisX: 0,
                axisY: 0,
                state: ShipState.Intact
            }));
        }
    }

    // generate a random ship direction
    function generateRandomDirection() private view returns (ShipDirection) {
        uint8 randomValue = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % 2);
        if (randomValue == 0) {
            return ShipDirection.Vertical;
        } else {
            return ShipDirection.Horizontal;
        }
    }

    function generateRandomAxis(uint8 shipLength, ShipDirection direction) private view returns (uint8 axisX, uint8 axisY) {
        uint8 gridSize = gridDimensionN; // Change this to your grid size
        require(gridSize > 0, "Grid size must be greater than 0");

        // Generate random X and Y coordinates within the grid size
        axisX = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, shipLength, direction))) % gridSize);
        axisY = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, shipLength, direction, axisX))) % gridSize);

        // Adjust X and Y coordinates based on ship length and direction to ensure the entire ship fits within the grid
        if (direction == ShipDirection.Horizontal) {
            // Check if the ship goes out of bounds on the X-axis
            while (axisX + shipLength > gridSize) {
                axisX = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, shipLength, direction, axisX))) % gridSize);
            }
        } else if (direction == ShipDirection.Vertical) {
            // Check if the ship goes out of bounds on the Y-axis
            while (axisY + shipLength > gridSize) {
                axisY = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, shipLength, direction, axisY))) % gridSize);
            }
        }

        return (axisX, axisY);
    }

    // Function to create Merkle tree leaves
    function createMerkleTreeLeaves(uint8[] memory shipLengths, uint8[] memory axisXs,
    uint8[] memory axisYs, ShipDirection[] memory directions) 
    public pure returns (bytes32[] memory) {
        require(shipLengths.length == axisXs.length && axisXs.length == axisYs.length && axisYs.length == directions.length, "Input arrays length mismatch");

        bytes32[] memory leaves = new bytes32[](shipLengths.length);
        for (uint256 i = 0; i < shipLengths.length; i++) {
            leaves[i] = keccak256(abi.encodePacked(shipLengths[i], axisXs[i], axisYs[i], directions[i]));
        }

        return leaves;
    }

    function calculateMerkleRootInternal(bytes32[] memory nodes) internal pure returns (bytes32) {
        if (nodes.length == 1) {
            return nodes[0];
        }

        uint256 n = nodes.length;
        require(n % 2 == 0, "Number of nodes should be even");

        bytes32[] memory parents = new bytes32[](n / 2);
        for (uint256 i = 0; i < n / 2; i++) {
            parents[i] = sha256(abi.encodePacked(nodes[i * 2], nodes[i * 2 + 1]));
        }

        return calculateMerkleRootInternal(parents);
    }

    function calculateMerkleRoot(bytes32[] memory leaves) external pure returns (bytes32) {
        require(leaves.length > 0, "At least one leaf is required");

        if (leaves.length == 1) {
            return leaves[0];
        }

        uint256 n = leaves.length;
        require(n % 2 == 0, "Number of leaves should be even");

        bytes32[] memory parents = new bytes32[](n / 2);
        for (uint256 i = 0; i < n / 2; i++) {
            parents[i] = sha256(abi.encodePacked(leaves[i * 2], leaves[i * 2 + 1]));
        }

        return calculateMerkleRootInternal(parents);
    }

    // check if the ship position is valid or is overlapping w.r.t. another ship
    function areShipsNonOverlapping(uint8[] memory startXPositions, uint8[] memory startYPositions,
    uint8[] memory shipLengths, ShipDirection[] memory directions) private view returns (bool) { 
        uint8 nShips = uint8(shipLengths.length);
        uint8[] memory shipLen; 
        uint8[] memory staPosX; 
        uint8[] memory staPosY; 
        ShipDirection[] memory dir= directions;

        {
            shipLen = shipLengths;
            staPosX = startXPositions;
            staPosX = startYPositions;
        }

        for (uint8 i = 0; i < nShips; i++) {
            uint8 startX = staPosX[i];
            uint8 startY = staPosY[i];
            uint8 shipLength = shipLen[i];
            ShipDirection direction = dir[i];

            for (uint8 j = 0; j < shipLength; j++) {
                uint8 x = getShipPositionX(startX, j, direction);
                uint8 y = getShipPositionY(startY, j, direction);

                if (!isWithinGrid(x, y, gridDimensionN)) {
                    return false;
                }

                if (doesOverlap(i, staPosX, staPosY, shipLen, dir)) {
                    return false;
                }
            }
        }

        return true;
    }

    function getShipPositionX(uint8 startX, uint8 j, ShipDirection direction) private pure returns (uint8) {
        return direction == ShipDirection.Horizontal ? startX + j : startX;
    }

    function getShipPositionY(uint8 startY, uint8 j, ShipDirection direction) private pure returns (uint8) {
        return direction == ShipDirection.Vertical ? startY + j : startY;
    }

    function isWithinGrid(uint8 x, uint8 y, uint8 gridSize) private pure returns (bool) {
        return x < gridSize && y < gridSize;
    }

    function doesOverlap(uint8 shipIndex, uint8[] memory startXPositions,
    uint8[] memory startYPositions, uint8[] memory shipLengths, ShipDirection[] memory directions
    ) private pure returns (bool) {
        for (uint8 k = 0; k < shipIndex; k++) {
            if (doShipsOverlap(shipIndex, k, startXPositions, startYPositions, shipLengths, directions)) {
                return true;
            }
        }
        return false;
    }

    function doShipsOverlap(uint8 shipIndexA, uint8 shipIndexB,
    uint8[] memory startXPositions, uint8[] memory startYPositions, uint8[] memory shipLengths,
    ShipDirection[] memory directions) private pure returns (bool) {
        uint8 startX_A = startXPositions[shipIndexA];
        uint8 startY_A = startYPositions[shipIndexA];
        uint8 shipLength_A = shipLengths[shipIndexA];
        ShipDirection direction_A = directions[shipIndexA];

        uint8 startX_B = startXPositions[shipIndexB];
        uint8 startY_B = startYPositions[shipIndexB];
        uint8 shipLength_B = shipLengths[shipIndexB];
        ShipDirection direction_B = directions[shipIndexB];

        for (uint8 m = 0; m < shipLength_A; m++) {
            uint8 x_A = getShipPositionX(startX_A, m, direction_A);
            uint8 y_A = getShipPositionY(startY_A, m, direction_A);

            for (uint8 n = 0; n < shipLength_B; n++) {
                uint8 x_B = getShipPositionX(startX_B, n, direction_B);
                uint8 y_B = getShipPositionY(startY_B, n, direction_B);

                if (x_A == x_B && y_A == y_B) {
                    return true;
                }
            }
        }

        return false;
    }

    // Logic related function

    function getShipPosition(address _address, uint8 index) external view returns (ShipPosition memory) {
        return players[_address].shipPositions[index];
    }

    /*function setShipPosition(uint8 _shipLength, uint8 _axisX, uint8 _axisY,
    ShipDirection _direction, address _player) internal {
        require(_shipLength > 0, "Ship length must be greater than 0");
        require(_axisX < gridDimensionN && _axisY < gridDimensionN, "Invalid coordinates");
        require(_direction == ShipDirection.Vertical || 
            _direction == ShipDirection.Horizontal,"Invalid ship direction");
        
        ShipPosition memory newShipPosition = ShipPosition({
            shipLength: _shipLength,
            axisX: _axisX,
            axisY: _axisY,
            direction: _direction,
            state: ShipState.Intact
        });

        players[_player].shipPositions.push(newShipPosition);
    }*/

    function setShipPositions(uint8[] memory shipLengths, uint8[] memory axisXs,
    uint8[] memory axisYs, ShipDirection[] memory directions, address player
    ) public {
        require(shipLengths.length == axisXs.length && axisXs.length == axisYs.length && 
            axisYs.length == directions.length, "Arrays length mismatch");

        PlayerModel storage playerModel = players[player];

        for (uint256 i = 0; i < shipLengths.length; i++) {
            ShipPosition memory newShip = ShipPosition({
                shipLength: shipLengths[i],
                axisX: axisXs[i],
                axisY: axisYs[i],
                direction: directions[i],
                state: ShipState.Intact
            });

            playerModel.shipPositions.push(newShip);
        }
    }

    function getSumOfShipSize() external view returns (uint8) {
        return sumOfShipSizes;
    }

    function getGridDimensionN() external view returns (uint8) {
        return gridDimensionN;
    }

    function setGridDimensionN(uint8 newValue) external{
        gridDimensionN = newValue;
    }

    function msgSender() external view returns(address sender) {
        if(msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly ("memory-safe"){
                // Load the 32 bytes word from memory with the 
                // address on the lower 20 bytes, and mask those.
                sender := and(mload(add(array, index)), 
                    0xffffffffffffffffffffffffffffffffffffffff)
            }
        } else {
            return msg.sender;
        }
    }

     function getShipLenghtFromIndex(uint8 _index) public view returns (uint8){
        if (_index >= 0 && _index < numShips) {
            return _index + 1;
        } else {
            return 0;
        }
     }

    function stringToUint8(string memory str) public pure returns (uint8) {
        bytes memory strBytes = bytes(str);
        require(strBytes.length > 0, "Empty string");

        uint8 result = 0;
        for (uint256 i = 0; i < strBytes.length; i++) {
            // Subtract the ASCII value of '0' (48) to get the digit
            uint8 digit = uint8(strBytes[i]) - 48; 
            // Check if the character is a valid digit
            require(digit <= 9, "Invalid character in the string"); 
            // Build the number digit by digit
            result = result * 10 + digit; 
        }

        return result;
    }

    // Battle related functions

    function getBattle(uint256 _battleId) public view returns (BattleModel memory) {
        return battles[_battleId];
    }

    function updateBattleById(uint256 _battleId, BattleModel memory _battle) 
    external onlyAuthorized returns (bool) {
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

    function setGamePhaseDetails(GamePhase _gamePhase, GamePhaseDetail memory _detail) external returns (bool) {
        gamePhaseMapping[_gamePhase] = _detail;
        return true;
    }

    function getLobbyByAddress(address _player) external view returns (LobbyModel memory) {
        return lobbyMap[_player];
    }

    function setLobbyByAddress(address _player, LobbyModel memory _lobbyModel) external returns (bool) {
        lobbyMap[_player] = _lobbyModel;
        return true;
    }

    // Merkle Tree related functions

    function getEncryptedMerkleTreeByBattleIdAndPlayer(uint256 _battleId, address _player) external view returns (string memory) {
        return encryptedMerkleTree[_battleId][_player];
    }

    function setEncryptedMerkleTreeByBattleIdAndPlayer(uint256 _battleId, address _player, string memory _merkleTree) external returns (bool) {
        encryptedMerkleTree[_battleId][_player] = _merkleTree;
        return true;
    }

    function encryptMerkleTree(bytes32 merkleTree) external pure returns (bytes32) {
        bytes32 hash = keccak256(abi.encodePacked(merkleTree));
        return hash;
    }

    // Utility function to convert bytes32 to string
    function bytes32ToString(bytes32 data) private pure returns (string memory) {
        bytes memory bytesString = new bytes(64);
        for (uint256 i = 0; i < 32; i++) {
            bytes1 char = bytes1(bytes32(uint256(data) * 2**(8 * i)));
            bytesString[i * 2] = char;
            bytesString[i * 2 + 1] = bytes1(0);
        }
        return string(bytesString);
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

    function getLastPlayTimeByBattleId (uint _battleId) external view returns (uint){
        return lastPlayTime[_battleId];
    }
    
    function setLastPlayTimeByBattleId(uint _battleId, uint _playTime) external returns (bool){
        lastPlayTime[_battleId] = _playTime;
        return true;
    }

    function getPositionsAttackedByBattleIdAndPlayer(uint256 _battleId, address _player) external view returns (uint8[] memory) {
        return positionsAttacked[_battleId][_player];
    }

    // check the correctness
    function setPositionsAttackedByBattleIdAndPlayer(uint256 _battleId, address _player, uint8 attackingPositionX, uint8 attackingPositionY) external returns (bool) {
        positionsAttacked[_battleId][_player] = [attackingPositionX, attackingPositionY];
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

    /*function getBattleVerification(uint256 _battleId, address _player) external view returns (VerificationStatus) {
        return battleVerification[_battleId][_player];
    }

    function setBattleVerification(uint256 _battleId, address _player, VerificationStatus _verificationStatus) external returns (bool) {
        battleVerification[_battleId][_player] = _verificationStatus;
        return true;
    }*/

    // Revealed leafs related functions

    function getRevealedLeafsByBattleIdAndPlayer(uint256 _battleId, address _player) external view returns (uint8) {
        return revealedLeafs[_battleId][_player];
    }

    function setRevealedLeafsByBattleIdAndPlayer(uint256 _battleId, address _player, uint8 _leafs) external returns (bool) {
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

/*

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