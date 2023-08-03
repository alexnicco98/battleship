// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma experimental ABIEncoderV2;

import "./interfaces/IntBattleshipStorage.sol";
import "./libs/MerkleProof.sol";

contract BattleshipLogic is IntBattleshipStruct {

    /**     TODO: check the code for possible mistake,
            and try if ShipPosition is compatible with other contracts**/
    uint8[] private shipSizes; // Array of ship lengths
    // Mapping of shipLength to array of corresponding indexes
    mapping(uint8 => uint8[]) private shipIndexes; 
    // Mapping of shipLength index to shipLength value
    mapping(uint8 => uint8) private shipFromIndex; 
    // Mapping of shipLength to shipPosition
    mapping(uint8 => ShipPosition) private shipPositionMapping; 
    uint8 public sumOfShipSizes;
    uint8 public gridDimensionN;
    uint8 private gridSquare;

    constructor() {
        gridDimensionN = 10;
        initializeShipSizes();
        initializeShipIndexes();
        initializeShipFromIndex();
        initializeShipPositionMapping();
        gridSquare = gridDimensionN * gridDimensionN;
    }

    function initializeShipSizes() private {
        shipSizes = new uint8[](gridDimensionN - 1);
        for (uint8 i = 0; i < gridDimensionN - 1; i++) {
            shipSizes[i] = i + 1;
            sumOfShipSizes += shipSizes[i];
        }
        
    }

    function initializeShipIndexes() private {
        for (uint8 i = 0; i < sumOfShipSizes; i++) {
            shipIndexes[shipSizes[i]].push(i);
        }
    }

    function initializeShipFromIndex() private {
        for (uint8 i = 0; i < sumOfShipSizes; i++) {
            shipFromIndex[i] = shipSizes[i];
        }
    }

    // place all the ships in a random order
    function initializeShipPositionMapping() private {
        require(shipSizes.length > 0, "Ship sizes must be initialized");
        require(gridDimensionN > 0, "Grid dimension must be greater than 0");
        require(sumOfShipSizes > 0, "Sum of ship sizes must be greater than 0");

        // Generate random positions and directions for the ships
        ShipDirection[] memory shipDirections = new ShipDirection[](gridDimensionN - 1);
        uint8[] memory shipStartXPositions = new uint8[](gridDimensionN - 1);
        uint8[] memory shipStartYPositions = new uint8[](gridDimensionN - 1);

        for (uint8 i = 0; i < gridDimensionN - 1; i++) {
            shipDirections[i] = generateRandomDirection();
            (shipStartXPositions[i], shipStartYPositions[i]) = generateRandomAxis(shipSizes[i], shipDirections[i]);
        }

        // Verify that the ships do not overlap
        require(areShipsNonOverlapping(shipStartXPositions, shipStartYPositions, shipSizes, shipDirections), "Ships overlap");

        // Save the ship positions and lengths in the shipPositionMapping
        for (uint8 i = 0; i < sumOfShipSizes; i++) {
            uint8 shipLength = shipSizes[i];
            ShipPosition memory shipPosition = ShipPosition({
                shipLength: shipSizes[i],
                direction: shipDirections[i],
                axisX: shipStartXPositions[i],
                axisY: shipStartYPositions[i],
                state: ShipState.Intact 
            });

            shipPositionMapping[shipLength] = shipPosition;
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



    // check if the ship position is valid or is overlapping w.r.t. another ship
    function areShipsNonOverlapping(uint8[] memory startXPositions, uint8[] memory startYPositions,
        uint8[] memory shipLengths, ShipDirection[] memory directions) private pure returns (bool) {
        uint8 gridSize = 10; // Change this to your grid size
        uint8 nShips = uint8(shipLengths.length);

        for (uint8 i = 0; i < nShips; i++) {
            uint8 startX = startXPositions[i];
            uint8 startY = startYPositions[i];
            uint8 shipLength = shipLengths[i];
            ShipDirection direction = directions[i];

            for (uint8 j = 0; j < shipLength; j++) {
                uint8 x = direction == ShipDirection.Horizontal ? startX + j : startX;
                uint8 y = direction == ShipDirection.Vertical ? startY + j : startY;

                // Check if the ship position is out of bounds or overlaps with other ships
                if (x >= gridSize || y >= gridSize) {
                    return false;
                }

                // For each new ship position, check that it does not overlap with the previous ships
                for (uint8 k = 0; k < i; k++) {
                    uint8 otherStartX = startXPositions[k];
                    uint8 otherStartY = startYPositions[k];
                    uint8 otherShipLength = shipLengths[k];
                    ShipDirection otherDirection = directions[k];

                    for (uint8 m = 0; m < otherShipLength; m++) {
                        uint8 otherX = otherDirection == ShipDirection.Horizontal ? otherStartX + m : otherStartX;
                        uint8 otherY = otherDirection == ShipDirection.Vertical ? otherStartY + m : otherStartY;

                        if (x == otherX && y == otherY) {
                            return false;
                        }
                    }
                }
            }
        }

        return true;
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

    function getPositionsOccupiedByAllShips() external view returns (uint8[] memory) {
        uint8[] memory allShipPositions = new uint8[](gridDimensionN);

        uint8 currentIndex = 0;
        for (uint8 i = 0; i < shipSizes.length; i++) {
            ShipPosition memory shipPos = shipPositionMapping[shipSizes[i]];
            uint8 axisX;
            uint8 axisY;
            (axisX, axisY) = generateRandomAxis(shipPos.shipLength, shipPos.direction);

            if (shipPos.direction == ShipDirection.Horizontal) {
                for (uint8 j = 0; j < shipPos.shipLength; j++) {
                    allShipPositions[currentIndex] = axisX + j + axisY * gridDimensionN;
                    currentIndex++;
                }
            } else if (shipPos.direction == ShipDirection.Vertical) {
                for (uint8 j = 0; j < shipPos.shipLength; j++) {
                    allShipPositions[currentIndex] = axisX + (axisY + j) * gridDimensionN;
                    currentIndex++;
                }
            }
        }

        return allShipPositions;
    }

     function msgSender() external view returns(address sender) {
        if(msg.sender == address(this)) {
            bytes memory array = msg.data;
            uint256 index = msg.data.length;
            assembly {
                // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
                sender := and(mload(add(array, index)), 0xffffffffffffffffffffffffffffffffffffffff)
            }
        } else {
            return msg.sender;
        }
    }

     function getShipTypeFromIndex(uint8 _index) public view returns (uint8){
        if (_index >= 0 && _index < sumOfShipSizes) {
            // Ship length is from 1 to n-1 (index+1) for gridDimensionN = 10
            return _index + 1;
        } else {
            return 0; // 0 represents None
        }
     }
     
     
    function getShipInxesFromShipLength(uint8 _shipLength) external view returns (uint8[] memory) {
        return shipIndexes[_shipLength];
    }

    function getSlice(uint256 begin, uint256 end, string memory text) public pure returns (string memory) {
        bytes memory a = new bytes(end - begin + 1);
        for (uint i = 0; i <= end - begin; i++) {
            a[i] = bytes(text)[i + begin - 1];
        }
        return string(a);
    }
    
    function getBytes32FromBytes(bytes memory value, uint index) public pure returns(bytes32)
    {
        bytes32 el;
        uint position = 32 * (index + 1);
        //Require That the length of the bytes covers the position to be read from
        require(value.length >= position, "The value requested is not within the range of the bytes");
       assembly {
        el := mload(add(value, position))
        }
        
        return el;
    }

     function stringToUint8(string memory str) public pure returns (uint8) {
        bytes memory strBytes = bytes(str);
        require(strBytes.length > 0, "Empty string");

        uint8 result = 0;
        for (uint256 i = 0; i < strBytes.length; i++) {
            uint8 digit = uint8(strBytes[i]) - 48; // Subtract the ASCII value of '0' (48) to get the digit
            require(digit <= 9, "Invalid character in the string"); // Check if the character is a valid digit
            result = result * 10 + digit; // Build the number digit by digit
        }

        return result;
    }

    function getShipPosition(string memory positionKey) internal view returns (ShipPosition memory) {
        return shipPositionMapping[stringToUint8(positionKey)];
    }
     

    /*function getOrderedPositionsAndAxis(string memory positions) external view returns(uint16[] memory, AxisType[5] memory){
        AxisType[] memory axis = new AxisType[](gridDimensionN - 1);
        uint16[] memory orderedPositions = new uint16[](sumOfShipSizes);
        uint8[] memory shipCounts = new uint8[](gridDimensionN - 1);
        ShipPosition memory shipPosition = ShipPosition(0, AxisType.None, ShipState.None);
        string memory shipPositionKey = "";

        for (uint8 i = 0; i < gridDimensionN - 1; i++) {
            axis[i] = AxisType.None;
        }

         for(uint16 i = 0; i < 400; i+=4)
         {

            shipPositionKey = getSlice(i+1, i+2, positions);
            // shipSizes[i] to access shipPositionMapping
            shipPosition = getShipPosition(shipPositionKey);
            if (shipPosition.shipLength >= 1 && shipPosition.shipLength <= sumOfShipSizes - 1) {
                if (axis[shipPosition.shipLength - 1] == AxisType.None) {
                    axis[shipPosition.shipLength - 1] = shipPosition.axis;
                }
                orderedPositions[shipCounts[shipPosition.shipLength - 1]] = (i / 4) + 1;
                shipCounts[shipPosition.shipLength - 1]++;
            }
             
             
         }
         

         return (orderedPositions, axis);
     }
     
    
    function CheckEqualArray(uint8[] memory _arr1, uint8[] memory _arr2) external pure returns (bool)
    {
        if(_arr1.length != _arr2.length) return false;
        for(uint i = 0; i < _arr1.length; i++)
        {
            if(_arr1[i] != _arr2[i]) return false;
        }
        return true;
    }

    function getSliceOfBytesArray(bytes memory _bytesArray, uint16 _indexStart, uint16 _indexStop) external pure returns(bytes memory)
    {
        bytes memory value = new bytes(_indexStop-_indexStart+1);
        uint position = 32 * (_indexStop + 1);
        require(_bytesArray.length >= position, "The value requested is not within the range of the bytes");
        
        for(uint i=0;i<=_indexStart-_indexStart;i++){
            value[i] = _bytesArray[i+_indexStart-1];
        }

        return value;
    }

    */
    
    

     
}
