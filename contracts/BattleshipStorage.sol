// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
pragma abicoder v2;

import "./libraries/IntBattleshipStruct.sol";

contract BattleshipStorage {
    
    // in the next development, should be a non-fixed variable that
    // the host player chose at the moment of creation of the game
    uint8 private gridDimensionN = 4;
    uint8 private numShips = 2;
    uint256 private gameId;
    uint256 private maxTime = 4 seconds;// 3 minutes;
    uint256 private maxNumberOfMissiles;
    uint256 private minStakingAmount = uint(0.0001 ether);
    uint256 private totalNumberOfPlayers;
    address payable private owner;
    address private currentPlayer;
    address public sender;
    uint256 private rewardCommissionRate;
    uint256 private cancelCommissionRate;
    bool private isTest;
    uint8 public sumOfShipSizes = 0;
    uint8 private gridSquare;
    address public battleShipContractAddress;
    mapping(uint256 => IntBattleshipStruct.BattleModel) public battles; // saved on the blockchain
    mapping(address => IntBattleshipStruct.PlayerModel) private players;
    //mapping(address => bytes32[]) private proofs;

    //mapping(uint256 => mapping(address => mapping(uint256 => bytes32))) 
    //private revealedPositions;
    mapping(uint256 => mapping(address => uint8[2][])) private positionsAttacked;
    mapping(address => bytes32[]) private merkleNodes;
    mapping(uint256 => mapping(address => bytes32)) private merkleTreeRoot;
    mapping(uint256 => address) private turn;
    mapping(uint256 => uint256) private lastPlayTime;
    mapping(uint256 => mapping(address => IntBattleshipStruct.ShipPosition[])) correctPositionsHit;
    //mapping(uint256 => mapping(address => VerificationStatus)) private battleVerification;
    mapping(uint256 => mapping(address => bytes32)) private revealedLeaves;
    mapping(address => IntBattleshipStruct.LobbyModel) public lobbyMap; // saved on the blockchain
    mapping(IntBattleshipStruct.GamePhase => IntBattleshipStruct.GamePhaseDetail) public gamePhaseMapping; // saved on the blockchain
    //bytes32[] proof;
    //bytes32[] hashedDataSequence;

    event LogMessage(string _message);
    event LogsMessage(string _message1, string _message2, string _message3);
    event shipsToString(string[] _ship);
    event PlayerCheating(address _player);
    event Print();

    modifier onlyOwner() {
        string memory text = string(abi.encodePacked("BattleshipStorage: Only the owner can execute this transaction, ", addressToString(msg.sender)));
        require(msg.sender == owner, text);
        _;
    }

   /* modifier onlyCurrentPlayer() {
        //string memory text = string(abi.encodePacked("BattleshipStorage: Only the current player can execute this transaction ", addressToString(msg.sender)));
        require(msg.sender == currentPlayer, addressToString(msg.sender) );
        _;
    }*/

    modifier onlyAuthorized() {
        //address sender = msg.sender;
        bool isBattleShipContract = sender == battleShipContractAddress;
        require(isBattleShipContract || isTest, "Unauthorized access");
        _;
    }

    constructor(bool _isTest) { //, address _battleShipContractAddress
        gameId = 0;
        maxNumberOfMissiles = gridDimensionN * gridDimensionN;
        isTest = _isTest;
        //battleShipContractAddress = _battleShipContractAddress;
        //gameLogic = IntBattleshipLogic(_gameLogic);

        gamePhaseMapping[IntBattleshipStruct.GamePhase.Placement] = 
            IntBattleshipStruct.GamePhaseDetail(minStakingAmount, 
            minStakingAmount, IntBattleshipStruct.GamePhase.Placement, 
            maxTime);
        gamePhaseMapping[IntBattleshipStruct.GamePhase.Shooting] = 
            IntBattleshipStruct.GamePhaseDetail(minStakingAmount,
            minStakingAmount, IntBattleshipStruct.GamePhase.Shooting, 
            maxTime);
        gamePhaseMapping[IntBattleshipStruct.GamePhase.Gameover] = 
            IntBattleshipStruct.GamePhaseDetail(minStakingAmount, 
            minStakingAmount, IntBattleshipStruct.GamePhase.Gameover, 
            maxTime);
        initializeShipPositionMapping();
        gridSquare = gridDimensionN * gridDimensionN;
    }

    // Helper function to convert address to string
    function addressToString(address addr) public pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(addr)));
        return bytes32ToString(value);
    }
    
    function initializeShipPositionMapping() private {
        uint8 shipSizes;
        for (uint8 i = 0; i < numShips; i++) {
            shipSizes = i + 1;
            sumOfShipSizes += shipSizes;
        }
    }

    // generate a random ship direction
    function generateRandomDirection() private view returns (IntBattleshipStruct.ShipDirection) {
        uint8 randomValue = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty))) % 2);
        if (randomValue == 0) {
            return IntBattleshipStruct.ShipDirection.Vertical;
        } else {
            return IntBattleshipStruct.ShipDirection.Horizontal;
        }
    }

    function generateRandomAxis(uint8 shipLength, IntBattleshipStruct.ShipDirection direction) 
    private view returns (uint8 axisX, uint8 axisY) {
        uint8 gridSize = gridDimensionN; // Change this to your grid size
        require(gridSize > 0, "Grid size must be greater than 0");

        // Generate random X and Y coordinates within the grid size
        axisX = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, shipLength, direction))) % gridSize);
        axisY = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, shipLength, direction, axisX))) % gridSize);

        // Adjust X and Y coordinates based on ship length and direction to ensure the entire ship fits within the grid
        if (direction == IntBattleshipStruct.ShipDirection.Horizontal) {
            // Check if the ship goes out of bounds on the X-axis
            while (axisX + shipLength > gridSize) {
                axisX = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, shipLength, direction, axisX))) % gridSize);
            }
        } else if (direction == IntBattleshipStruct.ShipDirection.Vertical) {
            // Check if the ship goes out of bounds on the Y-axis
            while (axisY + shipLength > gridSize) {
                axisY = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, msg.sender, shipLength, direction, axisY))) % gridSize);
            }
        }

        return (axisX, axisY);
    }

    // Function to create Merkle tree leaf
    function createMerkleTreeLeaf(uint256 _state, address _player) 
    internal view returns (bytes32) {
        // Generate a random salt
        bytes32 salt = bytes32(uint256(keccak256(abi.encodePacked(block.timestamp))));

        // Calculate the value of the leaf node
        // I'm adding also the addrress because otherwise,
        // the leaf are equals for both players
       // bytes32 value = bytes32(_state) ^ salt ^ bytes32(uint256(uint160(_player)));

        // Calculate the value of the leaf node
        // , bytes32(uint256(uint160(_player)))
        bytes32 leaf = keccak256(abi.encodePacked(bytes32(_state), salt));

        return leaf;
    }

    function getMerkleTreeProof(address _player) external view returns (bytes32[] memory){
        return merkleNodes[_player];
    }

    function getMerkleTreeProofLength(address _player) external view returns (uint256){
        return merkleNodes[_player].length;
    }

    function getMerkleRoot(address _player) external view returns (bytes32) {
        bytes32[] storage nodes = merkleNodes[_player];
        
        // Ensure there are nodes in the array
        require(nodes.length > 0, "No Merkle nodes for this player");
        
        // Return the last node in the array, which should be the root
        return nodes[nodes.length - 1];
    }

    function calculateMerkleRoot(bytes32[][] memory _leaves, address _player)
    external returns (bytes32) {
        require(_leaves.length > 0, "At least one leaf is required");
        bytes32[] storage nodes = merkleNodes[_player];

        uint256 n = gridDimensionN;
        uint256 dim = n * 2;
        uint256 index = 0;
        bytes32[] memory newRow = new bytes32[](dim);

        for (uint256 i = 0; i < n ; i++) {
            for (uint256 j = 0; j < n ; j+=2) {
                newRow[index] = sha256(abi.encodePacked(_leaves[i][j], _leaves[i][j + 1]));
                /*string memory test = string(abi.encodePacked("Merged --> AxisY: ",
                    uintToString(i), ", AxisX: ", uintToString(j), ", with --> axisY: ", 
                    uintToString(i), ", AxisX: ", uintToString(j+1)));
                emit LogMessage(test);*/
                nodes.push(newRow[index]);
                index++;
            } 
        }
        return calculateMerkleRootInternal(newRow, _player);
    }

    function calculateMerkleRootInternal(bytes32[] memory _nodes, address _player) 
    internal returns (bytes32) {
        uint256 n = _nodes.length;
        bytes32[] storage nodes = merkleNodes[_player];

        if (n == 1) {
            //nodes.push(_nodes[0]);
            return _nodes[0];
        }

        require(n % 2 == 0, "Number of nodes should be even");

        bytes32[] memory parents = new bytes32[](n / 2);
        uint256 index = 0;

        for (uint256 i = 0; i < n - 1; i += 2) {
            require(index < parents.length, "Index should be less that the size of the array");
            parents[index] = sha256(abi.encodePacked(_nodes[i], _nodes[i + 1]));
            nodes.push(parents[index]);
            index++;
        }

        return calculateMerkleRootInternal(parents, _player);
    } 


    function buildMerkleTree(bytes32[] storage hashArray) 
    internal returns (bytes32[] memory){
        uint256 count = hashArray.length; // number of leaves
        uint256 offset = 0;
        while (count > 0) {
            // Iterate 2 by 2, building the hash pairs
            for (uint256 i = 0; i < count - 1; i += 2) {
                hashArray.push(
                    _hashPair(hashArray[offset + i], hashArray[offset + i + 1])
                );
            }
            offset += count;
            count = count / 2;
        }
        return hashArray;
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? keccak256(abi.encodePacked(a, b)) : 
                       keccak256(abi.encodePacked(b, a));
    }

    /* this function is build for the specific case of 4 x 4 matrix */
    // calculate the Merkle proof from the specified _player, axisY, and axisX to the root
    function generateProof(address _player, uint8 axisY, uint8 axisX) 
    external view returns (bytes32[] memory) {
        uint256 n = gridDimensionN;
        require(axisY < n && axisX < n, "Invalid leaf coordinates");

        bytes32[] storage nodes = merkleNodes[_player];
        bytes32[] memory proof = new bytes32[](n);

        uint256 index = axisY * 2; 
        if (axisX == 2)
            index = index + 1; 
        uint256 offset = n * 2; 

        // first level have n * 2 elements
        proof[0] = nodes[index];
         // Calculate the parent index
        if (index == 0 || index == 1) {
            index = offset;
        } else if (index == 2 || index == 3) {
            index = offset + 1;
        } else if (index == 4 || index == 5) {
            index = offset + 2;
        } else if (index == 6 || index == 7){
            index = offset + 3;
        }
        offset = offset + (offset / 2); 

        // second level n elements
        proof[1] = nodes[index];
         // Calculate the parent index
        if (index == 8 || index == 9) {
            index = offset;
        } else if (index == 10 || index == 11) {
            index = offset + 1;
        }

        // third level n / 2 elements
        proof[2] = nodes[index];

        // the last level is always the root
        proof[n - 1] = nodes[nodes.length - 1];

        return proof;
    }

    function verifyProof(bytes32[] memory _proof, address _player, uint8 axisY, uint8 axisX) 
    external view returns (bool) {
        uint256 n = gridDimensionN;
        require(axisY < n && axisX < n, "Invalid leaf coordinates");

        bytes32[] storage nodes = merkleNodes[_player];

        uint256 index = axisY * 2; 
        if (axisX == 2)
            index = index + 1; 
        uint256 offset = n * 2; 

        // first level have n * 2 elements
        if(_proof[0] != nodes[index])
            return false;
         // Calculate the parent index
        if (index == 0 || index == 1) {
            index = offset;
        } else if (index == 2 || index == 3) {
            index = offset + 1;
        } else if (index == 4 || index == 5) {
            index = offset + 2;
        } else if (index == 6 || index == 7){
            index = offset + 3;
        }
        offset = offset + (offset / 2); 

        // second level n elements
        if(_proof[1] != nodes[index])
            return false;
         // Calculate the parent index
        if (index == 8 || index == 9) {
            index = offset;
        } else if (index == 10 || index == 11) {
            index = offset + 1;
        }

        // third level n / 2 elements
        if(_proof[2] != nodes[index])
            return false;

        // the last level is always the root
        if(_proof[n - 1] != nodes[nodes.length - 1])
            return false;

        return true;
    }
    

    function log2(uint256 x) internal pure returns (uint8) {
        uint8 result = 0;
        while (x > 1) {
            result++;
            x /= 2;
        }
        return result;
    }

    // Function to verify adversary's single leaf integrity
    function verifyAdversaryLeaf(uint256 _battleId, address _adversary, bytes32 _leaf, 
    bytes32 _root) external view returns (bool) {
        // Concatenate the adversary's leaf and their claimed root hash
        bytes memory concatenatedProof = abi.encodePacked(_leaf, _root);
        
        // Hash the concatenated proof
        bytes32 calculatedHash = keccak256(concatenatedProof);
        
        // Compare the calculated hash with the actual Merkle root of the adversary
        return calculatedHash == getMerkleTreeRootByBattleIdAndPlayer(_battleId, _adversary);
    }

    // check if the ship position is valid or is overlapping w.r.t. another ship
    function areShipsNonOverlapping(uint8[] memory startXPositions, 
    uint8[] memory startYPositions, uint8[] memory shipLengths, 
    IntBattleshipStruct.ShipDirection[] memory directions) private view returns (bool) { 
        uint8 nShips = uint8(shipLengths.length);
        uint8[] memory shipLen; 
        uint8[] memory staPosX; 
        uint8[] memory staPosY; 
        IntBattleshipStruct.ShipDirection[] memory dir= directions;

        {
            shipLen = shipLengths;
            staPosX = startXPositions;
            staPosX = startYPositions;
        }

        for (uint8 i = 0; i < nShips; i++) {
            uint8 startX = staPosX[i];
            uint8 startY = staPosY[i];
            uint8 shipLength = shipLen[i];
            IntBattleshipStruct.ShipDirection direction = dir[i];

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

    function getShipPositionX(uint8 startX, uint8 j, IntBattleshipStruct.ShipDirection direction) 
    private pure returns (uint8) {
        return direction == IntBattleshipStruct.ShipDirection.Horizontal ? startX + j : startX;
    }

    function getShipPositionY(uint8 startY, uint8 j, IntBattleshipStruct.ShipDirection direction) 
    private pure returns (uint8) {
        return direction == IntBattleshipStruct.ShipDirection.Vertical ? startY + j : startY;
    }

    function isWithinGrid(uint8 x, uint8 y, uint8 gridSize) private pure returns (bool) {
        return x < gridSize && y < gridSize;
    }

    function doesOverlap(uint8 shipIndex, uint8[] memory startXPositions,
    uint8[] memory startYPositions, uint8[] memory shipLengths, 
    IntBattleshipStruct.ShipDirection[] memory directions) private pure returns (bool) {
        for (uint8 k = 0; k < shipIndex; k++) {
            if (doShipsOverlap(shipIndex, k, startXPositions, startYPositions, 
            shipLengths, directions)) {
                return true;
            }
        }
        return false;
    }

    function doShipsOverlap(uint8 shipIndexA, uint8 shipIndexB,
    uint8[] memory startXPositions, uint8[] memory startYPositions, 
    uint8[] memory shipLengths, IntBattleshipStruct.ShipDirection[] memory directions) 
    private pure returns (bool) {
        uint8 startX_A = startXPositions[shipIndexA];
        uint8 startY_A = startYPositions[shipIndexA];
        uint8 shipLength_A = shipLengths[shipIndexA];
        IntBattleshipStruct.ShipDirection direction_A = directions[shipIndexA];

        uint8 startX_B = startXPositions[shipIndexB];
        uint8 startY_B = startYPositions[shipIndexB];
        uint8 shipLength_B = shipLengths[shipIndexB];
        IntBattleshipStruct.ShipDirection direction_B = directions[shipIndexB];

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

    function getNumShips() external view returns (uint8){
        return numShips;
    }

    function getShipPosition(address _address, uint8 _index) 
    external view returns (IntBattleshipStruct.ShipPosition memory) {
        return players[_address].shipPositions[_index];
    }

    function getShipPositionByAxis(address _player, uint8 _axisX, uint8 _axisY) 
    public view returns (IntBattleshipStruct.ShipPosition memory) {
        IntBattleshipStruct.PlayerModel storage player = players[_player];
        require(player.leafIndexX.length == sumOfShipSizes && player.leafIndexY.length
            == sumOfShipSizes && player.leafIndexShipPosition.length == sumOfShipSizes,
            "Arrays length mismatch");
        
        for (uint8 i = 0; i < sumOfShipSizes; i++) {
            if (player.leafIndexX[i] == _axisX && player.leafIndexY[i] == _axisY) {
                //emit LogMessage(uintToString(player.leafIndexShipPosition[i]));
                return player.shipPositions[player.leafIndexShipPosition[i]];
            }
        }
        
        // Ship not found, return a default ShipPosition
        IntBattleshipStruct.ShipPosition memory defaultShipPosition = IntBattleshipStruct.ShipPosition({
                shipLength: 0,
                direction: IntBattleshipStruct.ShipDirection.None,
                axisX: 0,
                axisY: 0,
                state: IntBattleshipStruct.ShipState.None
            });
        return defaultShipPosition;
    }

    function isHit(address _player, uint8 _axisX, uint8 _axisY) 
    external view returns (bool) {
        IntBattleshipStruct.PlayerModel storage player = players[_player];
        require(player.leafIndexX.length == sumOfShipSizes && player.leafIndexY.length
            == sumOfShipSizes && player.leafIndexShipPosition.length == sumOfShipSizes,
            "Arrays length mismatch");
        
        for (uint8 i = 0; i < sumOfShipSizes; i++) {
            if (player.leafIndexX[i] == _axisX && player.leafIndexY[i] == _axisY) {
                //emit LogMessage(uintToString(player.leafIndexShipPosition[i]));
                return true;
            }
        }
        
        // Ship not found
        return false;
    }

    function getMerkleTreeLeaf(address _address, uint8 _axisX, uint8 _axisY) 
    external view returns (bytes32) {
        return players[_address].leaves[_axisY][_axisX];
    }

    function getMerkleTreeLeaves(address _address) external view returns (bytes32[][] memory) {
        return players[_address].leaves;
    }

    function convertAndEmitShipPositions(IntBattleshipStruct.ShipPosition[] memory shipPositions) 
    public {
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

    function shipDirectionToString(IntBattleshipStruct.ShipDirection direction) 
    internal pure returns (string memory) {
        if (direction == IntBattleshipStruct.ShipDirection.Horizontal) {
            return "Horizontal";
        } else if (direction == IntBattleshipStruct.ShipDirection.Vertical) {
            return "Vertical";
        } else {
            return "Unknown";
        }
    } 

    function setShipPositions(uint8[] memory shipLengths, uint8[] memory axisXs,
    uint8[] memory axisYs, IntBattleshipStruct.ShipDirection[] memory directions, address player
    ) external {
        require(shipLengths.length == axisXs.length && axisXs.length == axisYs.length && 
            axisYs.length == directions.length, "Arrays length mismatch");

        IntBattleshipStruct.PlayerModel storage playerModel = players[player];

        for (uint8 i = 0; i < numShips; i++) {
            IntBattleshipStruct.ShipPosition memory newShip = IntBattleshipStruct.ShipPosition({
                shipLength: shipLengths[i],
                axisX: axisXs[i],
                axisY: axisYs[i],
                direction: directions[i],
                state: IntBattleshipStruct.ShipState.Intact
            });
            playerModel.shipPositions.push(newShip);
            // anti-cheat check
            if( playerModel.shipPositions.length > numShips){
                emit PlayerCheating(player);
                return;
            }
        }
        transformShipPosition(playerModel, player);
    }

    function transformShipPosition(IntBattleshipStruct.PlayerModel storage _playerModel, address _player) 
    internal {
        bool[][] memory shipMatrix = new bool[][](gridDimensionN);

        for (uint8 i = 0; i < gridDimensionN; i++) {
            shipMatrix[i] = new bool[](gridDimensionN);
            for (uint8 j = 0; j < gridDimensionN; j++) {
                shipMatrix[i][j] = false;
            }
        }

        for (uint8 i = 0; i < numShips; i++) {
            IntBattleshipStruct.ShipPosition memory ship = _playerModel.shipPositions[i];

            uint8 shipLength = ship.shipLength;
            uint8 axisX = ship.axisX;
            uint8 axisY = ship.axisY;
            IntBattleshipStruct.ShipDirection direction = ship.direction;

            if (direction == IntBattleshipStruct.ShipDirection.Horizontal) {
                if (axisX + shipLength > gridDimensionN) {
                    revert("Ship would go out of bounds horizontally");
                }
                for (uint8 j = axisX; j < axisX + shipLength; j++) {
                    //emit LogsMessage("Placing ship at", uint8ToString(j), uint8ToString(axisY));
                    shipMatrix[axisY][j] = true;
                    updatePlayerLeafIndexes(_playerModel, j, axisY, i);
                }
            } else if (direction == IntBattleshipStruct.ShipDirection.Vertical) {
                if (axisY + shipLength > gridDimensionN) {
                    revert("Ship would go out of bounds vertically");
                }
                for (uint8 j = axisY; j < axisY + shipLength; j++) {
                    //emit LogsMessage("Placing ship at", uint8ToString(axisX), uint8ToString(j));
                    shipMatrix[j][axisX] = true;
                    updatePlayerLeafIndexes(_playerModel, axisX, j, i);
                }
            }
        }

        for (uint8 i = 0; i < gridDimensionN; i++) {
            bytes32[] memory temporaryLeaf = new bytes32[](gridDimensionN);
            for (uint8 j = 0; j < gridDimensionN; j++) {
                temporaryLeaf[j] = shipMatrix[i][j] ? createMerkleTreeLeaf(1, _player) : 
                createMerkleTreeLeaf(0, _player);
            }
            _playerModel.leaves.push(temporaryLeaf);
        }
    }

    function updatePlayerLeafIndexes(IntBattleshipStruct.PlayerModel storage player, uint8 leafIndexX,
    uint8 leafIndexY,uint8 leafIndexShipPosition) internal {
        player.leafIndexX.push(leafIndexX);
        player.leafIndexY.push(leafIndexY);
        player.leafIndexShipPosition.push(leafIndexShipPosition);
    }

    function uint8ToString(uint8 _num) internal pure returns (string memory) {
        bytes memory numBytes = new bytes(1);
        numBytes[0] = bytes1(uint8(_num));

        return string(abi.encodePacked(numBytes));
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

    function msgSender() external view returns(address _sender) {
        if(msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly ("memory-safe"){
                // Load the 32 bytes word from memory with the 
                // address on the lower 20 bytes, and mask those.
                _sender := and(mload(add(array, index)), 
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

    function getBattle(uint256 _battleId) public view returns (IntBattleshipStruct.BattleModel memory) {
        return battles[_battleId];
    }

    function updateBattleById(uint256 _battleId, IntBattleshipStruct.BattleModel memory _battle, 
    IntBattleshipStruct.GamePhase _gamePhase) external onlyAuthorized returns (bool) {
        _battle.updatedAt = block.timestamp;
        _battle.gamePhase = _gamePhase;
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

    function getPlayerByAddress(address _address) 
    public view returns (IntBattleshipStruct.PlayerModel memory) {
        return players[_address];
    }

    function getContractOwner() public view returns (address) {
        return owner;
    }

    function setBattleshipContractAddress(address _address) 
    onlyOwner external returns (bool) {
        battleShipContractAddress = _address;
        return true;
    }

    /*function updatePlayerByAddress(address _player, PlayerModel memory _playerModel)
     onlyAuthorized external returns (bool) {
        _playerModel.updatedAt = block.timestamp;
        if (_playerModel.createdAt == 0) {
            _playerModel.createdAt = block.timestamp;
        }
        players[_player] = _playerModel;
        return true;
    }*/

    // Game mode and lobby related functions

    function getGamePhaseDetails(IntBattleshipStruct.GamePhase _gamePhase) 
    external view returns (IntBattleshipStruct.GamePhaseDetail memory) {
        return gamePhaseMapping[_gamePhase];
    }

    function setGamePhaseDetails(IntBattleshipStruct.GamePhase _gamePhase, IntBattleshipStruct.GamePhaseDetail memory _detail) 
    external returns (bool) {
        gamePhaseMapping[_gamePhase] = _detail;
        return true;
    }

    function getLobbyByAddress(address _player) external view returns (IntBattleshipStruct.LobbyModel memory) {
        return lobbyMap[_player];
    }

    function getLobbyByPlayer(address _player) internal view returns (IntBattleshipStruct.LobbyModel memory) {
        return lobbyMap[_player];
    }

    function setLobbyByAddress(address _player, IntBattleshipStruct.LobbyModel memory _lobbyModel) 
    external returns (bool) {
        lobbyMap[_player] = _lobbyModel;
        return true;
    }

    // Merkle Tree related functions

    function encryptMerkleTree(bytes32 merkleTree) external pure returns (bytes32) {
        bytes32 hash = keccak256(abi.encodePacked(merkleTree));
        return hash;
    }

    // Utility function to convert bytes32 to string
    function bytes32ToString(bytes32 data) internal pure returns (string memory) {
        bytes memory bytesString = new bytes(64);
        for (uint256 i = 0; i < 32; i++) {
            bytes1 char = bytes1(bytes32(uint256(data) * 2**(8 * i)));
            bytesString[i * 2] = char;
            bytesString[i * 2 + 1] = bytes1(0);
        }
        return string(bytesString);
    }

    /*function getRevealedPositionValueByBattleIdAndPlayer(uint256 _battleId, 
    address _revealingPlayer, uint256 _position) external view returns (bytes32) {
        return revealedPositions[_battleId][_revealingPlayer][_position];
    }

    function setRevealedPositionByBattleIdAndPlayer(uint256 _battleId, 
    address _revealingPlayer, uint256 _position, bytes32 _value) external returns (bool) {
        revealedPositions[_battleId][_revealingPlayer][_position] = _value;
        return true;
    }*/

    function getMerkleTreeRootByBattleIdAndPlayer(uint256 _battleId, address _player) 
    public view returns (bytes32) {
        return merkleTreeRoot[_battleId][_player];
    }

    function setMerkleTreeRootByBattleIdAndPlayer(uint256 _battleId, address _player, 
    bytes32 _root) external returns (bool) {
        merkleTreeRoot[_battleId][_player] = _root;
        return true;
    }

    // Position attack related functions

    function getLastPlayTimeByBattleId (uint256 _battleId) external view returns (uint256){
        return lastPlayTime[_battleId];
    }
    
    function setLastPlayTimeByBattleId(uint256 _battleId, uint256 _playTime) 
    external returns (bool){
        lastPlayTime[_battleId] = _playTime;
        currentPlayer = battles[_battleId].client;
        return true;
    }

    function getPositionsAttackedLength(uint256 _battleId, address _player) 
    external view returns (uint256) {
        return positionsAttacked[_battleId][_player].length;
    }

    function getLastPositionsAttackedByBattleIdAndPlayer(uint256 _battleId, address _player) 
    external view returns (uint8[2] memory) {
        
        if (positionsAttacked[_battleId][_player].length == 0) {
            // Return a value that can be easily detected as uninitialized
            return [type(uint8).max, type(uint8).max]; 
        }

        uint8[2] memory lastPositionAttacked = positionsAttacked[_battleId][_player][positionsAttacked[_battleId][_player].length - 1];
        return lastPositionAttacked;
    }

    function setPositionsAttackedByBattleIdAndPlayer(uint256 _battleId, address _player, 
    uint8 _attackingPositionX, uint8 _attackingPositionY, address _currentPlayer) external returns (bool) {
        if( _currentPlayer == currentPlayer){
            revert("The player that call this function should be different each time");
        }
        switchPlayer(_battleId);
        positionsAttacked[_battleId][_player].push([_attackingPositionY, 
        _attackingPositionX]);
        //sender = msg.sender;
        //currentPlayer = battles[_battleId].client;
        return true;
    }

    function switchPlayer(uint256 _battleId) internal{
        currentPlayer = (battles[_battleId].client == currentPlayer) ? battles[_battleId].host : battles[_battleId].client;
    }

    /*function setCurrentPlayer(address _player) external{
       currentPlayer = _player; 
    }

    function getCurrentPlayer() external view returns(address){
        return currentPlayer;
    }

    function getSender() external view returns(address){
        return sender;
    }*/

    // Correct positions hit related functions

    function getCorrectPositionsHitByBattleIdAndPlayer(uint256 _battleId, address _player) 
    external view returns (IntBattleshipStruct.ShipPosition[] memory) {
        return correctPositionsHit[_battleId][_player];
    }

    function setCorrectPositionsHitByBattleIdAndPlayer(uint256 _battleId, address _player, 
    IntBattleshipStruct.ShipPosition memory _positions) external returns (bool) {
        correctPositionsHit[_battleId][_player].push(_positions);
        return true;
    }

    // Battle verification related functions

    /*function getBattleVerification(uint256 _battleId, address _player) 
    external view returns (VerificationStatus) {
        return battleVerification[_battleId][_player];
    }

    function setBattleVerification(uint256 _battleId, address _player, 
    VerificationStatus _verificationStatus) external returns (bool) {
        battleVerification[_battleId][_player] = _verificationStatus;
        return true;
    }*/

    // Revealed leafs related functions

    function getRevealedLeavesByBattleIdAndPlayer(uint256 _battleId, address _player) 
    external view returns (bytes32) {
        return revealedLeaves[_battleId][_player];
    }

    function setRevealedLeavesByBattleIdAndPlayer(uint256 _battleId, address _player, 
    bytes32 _leaves) external returns (bool) {
        revealedLeaves[_battleId][_player] = _leaves;
        return true;
    }

    /*function getProofByIndexAndPlayer(uint256 _index, address _player) external view returns (bytes32) {
        return proofs[_player][_index];
    }

    function setProofByIndexAndPlayer(uint256 _index, address _player, bytes32 _proof) external returns (bool) {
        proofs[_player][_index] = _proof;
        return true;
    }*/

    // Miscellaneous functions

    function getTurnByBattleId(uint256 _battleId) external view returns(address){
        return turn[_battleId];
    }
    
    function setTurnByBattleId(uint256 _battleId, address _turn) external returns (bool){
        turn[_battleId]  = _turn;
        return true;
    }
    
}

/*

    function setPlayerAddresses(address[] memory _playerAddresses) 
    external onlyOwner returns (bool) {
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
        return maxTime;
    }

    function setMinTimeRequiredForPlayerToRespond(uint256 _minTime) 
    external onlyOwner returns (bool) {
        maxTime = _minTime;
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

    function getRewardCommissionRate() external view returns (uint256) {
        return rewardCommissionRate;
    }

    function setRewardCommissionRate(uint256 _commissionRate) 
    external onlyOwner returns (bool) {
        rewardCommissionRate = _commissionRate;
        return true;
    }

    function getCancelCommissionRate() external view returns (uint256) {
        return cancelCommissionRate;
    }

    function setCancelCommissionRate(uint256 _commissionRate) 
    external onlyOwner returns (bool) {
        cancelCommissionRate = _commissionRate;
        return true;
    }

    function setIsTest(bool _isTest) external onlyOwner returns (bool) {
        isTest = _isTest;
        return true;
    }*/