// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
pragma abicoder v2;

import "./libraries/IntBattleshipStruct.sol";

contract BattleshipStorage {
    
    // in the next development, should be a non-fixed variable that
    // the host player chose at the moment of creation of the game
    uint8 private gridDimensionN = 8;
    uint8 private numShips = 4;
    uint256 private gameId;
    uint256 private maxTime = 3 minutes; // 3 minutes;
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
    mapping(uint256 => mapping(address => uint8[2][])) private positionsAttacked;
    mapping(address => bytes32[]) private merkleNodes;
    mapping(uint256 => mapping(address => bytes32)) private merkleTreeRoot;
    mapping(uint256 => address) private turn;
    mapping(uint256 => uint256) private lastPlayTime;
    mapping(uint256 => mapping(address => IntBattleshipStruct.ShipPosition[])) correctPositionsHit;
    mapping(address => IntBattleshipStruct.LobbyModel) public lobbyMap; // saved on the blockchain
    mapping(IntBattleshipStruct.GamePhase => IntBattleshipStruct.GamePhaseDetail) public gamePhaseMapping; // saved on the blockchain

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

    constructor(bool _isTest) { 
        gameId = 0;
        maxNumberOfMissiles = gridDimensionN * gridDimensionN;
        isTest = _isTest;

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
    function addressToString(address addr) internal pure returns (string memory) {
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
        bytes32 salt = bytes32(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty,  _player))));

        // Calculate the value of the leaf node
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

    function log2(uint256 x) internal pure returns (uint256) {
        require(x > 0, "Input must be greater than zero");

        uint256 result = 0;
        while (x > 1) {
            x >>= 1;
            result += 1;
        }
        return result;
    }

    function calculateMerkleRoot(bytes32[][] memory _leaves, address _player)
    external returns (bytes32) {
        require(_leaves.length == gridDimensionN, "leaves sgould be of dimension gridDimensionN");
        bytes32[] storage nodes = merkleNodes[_player];

        uint256 n = gridDimensionN;
        uint256 dim = (n * n) / 2;
        uint256 index = 0;
        bytes32[] memory newRow = new bytes32[](dim);

        for (uint256 i = 0; i < n ; i++) {
            for (uint256 j = 0; j < n ; j+=2) {
                newRow[index] = sha256(abi.encodePacked(_leaves[i][j], _leaves[i][j + 1]));
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

    /* this function is build for the specific case of 4 x 4 matrix */
    // calculate the Merkle proof from the specified _player, axisY, and axisX to the root
    function generateProof(address _player, uint8 axisY, uint8 axisX, uint8 dim) 
    external view returns (bytes32[] memory) {
        if( dim == 4){
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
        }else if( dim == 8){
            uint256 n = gridDimensionN;
            require(axisY < n && axisX < n, "Invalid leaf coordinates");

            bytes32[] storage nodes = merkleNodes[_player];
            bytes32[] memory proof = new bytes32[](n - 2);

            // Calculate the initial index based on the provided coordinates
            uint256 index = axisY * 2; 
            if (axisX == 2)
                index = index + 1; 
            uint256 elements = (n* n) / 2; // 32
            uint256 offset = elements; // 32

            // first level have 32 elements
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
            } else if (index == 8 || index == 9){
                index = offset + 4;
            } else if (index == 10 || index == 11){
                index = offset + 5;
            } else if (index == 12 || index == 13){
                index = offset + 6;
            } else if (index == 14 || index == 15){
                index = offset + 7;
            } else if (index == 16 || index == 17){
                index = offset + 8;
            } else if (index == 18 || index == 19){
                index = offset + 9;
            } else if (index == 20 || index == 21){
                index = offset + 10;
            } else if (index == 22 || index == 23){
                index = offset + 11;
            } else if (index == 24 || index == 25){
                index = offset + 12;
            } else if (index == 26 || index == 27){
                index = offset + 13;
            } else if (index == 28 || index == 29){
                index = offset + 14;
            } else if (index == 30 || index == 31){
                index = offset + 15;
            }
            offset = offset + (elements / 2); 
            elements = elements / 2; // 16

            // second level 16 elements
            proof[1] = nodes[index];
            // Calculate the parent index
            if (index == 32 || index == 33) {
                index = offset;
            } else if (index == 34 || index == 35) {
                index = offset + 1;
            } else if (index == 36 || index == 37) {
                index = offset + 2;
            } else if (index == 38 || index == 39) {
                index = offset + 3;
            } else if (index == 40 || index == 41) {
                index = offset + 4;
            } else if (index == 42 || index == 43) {
                index = offset + 5;
            } else if (index == 44 || index == 45) {
                index = offset + 6;
            } else if (index == 46 || index == 47) {
                index = offset + 7;
            }
            offset = offset + (elements / 2);
            elements = elements / 2; // 8

            // third level 8 elements
            proof[2] = nodes[index];
            // Calculate the parent index
            if (index == 48 || index == 49) {
                index = offset;
            } else if (index == 50 || index == 51) {
                index = offset + 1;
            } else if (index == 50 || index == 51) {
                index = offset + 1;
            } else if (index == 52 || index == 53) {
                index = offset + 2;
            } else if (index == 54 || index == 55) {
                index = offset + 3;
            }
            offset = offset + (elements / 2);
            elements = elements / 2; // 4

            // fourth level 4 elements
            proof[3] = nodes[index];
            // Calculate the parent index
            if (index == 56 || index == 57) {
                index = offset;
            } else if (index == 58 || index == 59) {
                index = offset + 1;
            }
            offset = offset + (elements / 2);
            elements = elements / 2; // 2

            // fifth level 2 elements
            proof[4] = nodes[index];
            // Calculate the parent index
            if (index == 60 || index == 61) {
                index = offset;
            }

            // the last level is always the root
            proof[5] = nodes[nodes.length - 1];

            return proof;
        }else{
            revert("The dimension is not right!");
        }
    }

    function verifyProof(bytes32[] memory _proof, address _player, uint8 axisY, uint8 axisX, uint8 dim) 
    external view returns (bool) {
        if( dim == 4){
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
        }else if( dim == 8){
            uint256 n = gridDimensionN;
            require(axisY < n && axisX < n, "Invalid leaf coordinates");

            bytes32[] storage nodes = merkleNodes[_player];

            uint256 index = axisY * 2; 
            if (axisX == 2)
                index = index + 1; 
            uint256 elements = (n * n) / 2; // 32
            uint256 offset = elements; // 32

            // Verify the first level
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
            } else if (index == 8 || index == 9){
                index = offset + 4;
            } else if (index == 10 || index == 11){
                index = offset + 5;
            } else if (index == 12 || index == 13){
                index = offset + 6;
            } else if (index == 14 || index == 15){
                index = offset + 7;
            } else if (index == 16 || index == 17){
                index = offset + 8;
            } else if (index == 18 || index == 19){
                index = offset + 9;
            } else if (index == 20 || index == 21){
                index = offset + 10;
            } else if (index == 22 || index == 23){
                index = offset + 11;
            } else if (index == 24 || index == 25){
                index = offset + 12;
            } else if (index == 26 || index == 27){
                index = offset + 13;
            } else if (index == 28 || index == 29){
                index = offset + 14;
            } else if (index == 30 || index == 31){
                index = offset + 15;
            }
            offset = offset + (elements / 2); 
            elements = elements / 2; // 16

            // Verify the second level
            if(_proof[1] != nodes[index])
                return false;
            // Calculate the parent index
            if (index == 32 || index == 33) {
                index = offset;
            } else if (index == 34 || index == 35) {
                index = offset + 1;
            } else if (index == 36 || index == 37) {
                index = offset + 2;
            } else if (index == 38 || index == 39) {
                index = offset + 3;
            } else if (index == 40 || index == 41) {
                index = offset + 4;
            } else if (index == 42 || index == 43) {
                index = offset + 5;
            } else if (index == 44 || index == 45) {
                index = offset + 6;
            } else if (index == 46 || index == 47) {
                index = offset + 7;
            }
            offset = offset + (elements / 2);
            elements = elements / 2; // 8

            // Verify the third level
            if(_proof[2] != nodes[index])
                return false;
            // Calculate the parent index
            if (index == 48 || index == 49) {
                index = offset;
            } else if (index == 50 || index == 51) {
                index = offset + 1;
            } else if (index == 52 || index == 53) {
                index = offset + 2;
            } else if (index == 54 || index == 55) {
                index = offset + 3;
            }
            offset = offset + (elements / 2);
            elements = elements / 2; // 4

            // Verify the fourth level
            if(_proof[3] != nodes[index])
                return false;
            // Calculate the parent index
            if (index == 56 || index == 57) {
                index = offset;
            } else if (index == 58 || index == 59) {
                index = offset + 1;
            }
            offset = offset + (elements / 2);
            elements = elements / 2; // 2

            // Verify the fifth level
            if(_proof[4] != nodes[index])
                return false;
            // Calculate the parent index
            if (index == 60 || index == 61) {
                index = offset;
            }

            // Verify the last level (root)
            if(_proof[5] != nodes[nodes.length - 1])
                return false;

            return true;
        }else{
            revert("The dimension is not right!");
        }
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
                return player.shipPositions[player.leafIndexShipPosition[i]];
            }
        }
        
        // Ship not found, return a default ShipPosition
        IntBattleshipStruct.ShipPosition memory defaultShipPosition = IntBattleshipStruct.ShipPosition({
                shipLength: 0,
                direction: IntBattleshipStruct.ShipDirection.None,
                axisX: _axisX,
                axisY: _axisY,
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
                // I set the revert because the game when I call this function is not
                // set yet, and so should be too difficult to set it only to allow 
                // the opposite player to win (consequnce of the cheat)
                revert("The number of ships allowed must be respected!");
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

     function getShipLenghtFromIndex(uint8 _index) external view returns (uint8){
        if (_index >= 0 && _index < numShips) {
            return _index + 1;
        } else {
            return 0;
        }
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

    function setLobbyByAddress(address _player, IntBattleshipStruct.LobbyModel memory _lobbyModel) 
    external returns (bool) {
        lobbyMap[_player] = _lobbyModel;
        return true;
    }

    // Merkle Tree related functions

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

    function getLastPlayTimeByBattleId(uint256 _battleId) external view returns (uint256){
        return lastPlayTime[_battleId];
    }
    
    function setLastPlayTimeByBattleId(uint256 _battleId, uint256 _playTime) 
    external returns (bool){
        lastPlayTime[_battleId] = _playTime;
        return true;
    }

    function setLastPlayTimeFirstTime(uint256 _battleId, uint256 _playTime) 
    external returns (bool){
        lastPlayTime[_battleId] = _playTime;
        currentPlayer = battles[_battleId].client;
        return true;
    }

    function getPositionsAttackedLength(uint256 _battleId, address _player) 
    external view returns (uint256) {
        return positionsAttacked[_battleId][_player].length;
    }

    function getAllPositionsAttacked(uint256 _battleId, address _player)
    external view returns (uint8[2][] memory){
        return positionsAttacked[_battleId][_player];
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

    // Miscellaneous functions

    function getTurnByBattleId(uint256 _battleId) external view returns(address){
        return turn[_battleId];
    }
    
    function setTurnByBattleId(uint256 _battleId, address _turn) external returns (bool){
        turn[_battleId]  = _turn;
        return true;
    }
    
}