// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma experimental ABIEncoderV2;

import "./interfaces/IntBattleshipStorage.sol";
import "./libs/MerkleProof.sol";

contract BattleshipLogic is IntBattleshipStruct {

    struct ShipPositionMapping {
        uint8 shipLength;
        ShipDirection direction;
        uint8 axisX;
        uint8 axisY;
        ShipState state;
    }
    
    uint8[] public shipSizes; // Array of ship lengths
    ShipPositionMapping[] public shipPositionMapping;
    uint8 public numShips;
    uint8 public sumOfShipSizes;
    uint8 public gridDimensionN;
    uint8 private gridSquare;

    constructor() {
        gridDimensionN = 4;
        numShips = 2;
        initializeShipSizes();
        initializeShipPositionMapping();
        gridSquare = gridDimensionN * gridDimensionN;
    }

    function initializeShipSizes() private {
        shipSizes = new uint8[](numShips);
        for (uint8 i = 0; i < numShips; i++) {
            shipSizes[i] = i + 1;
            sumOfShipSizes += shipSizes[i];
        }
    }

    function initializeShipPositionMapping() private {
        for (uint8 i = 0; i < numShips; i++) {
            shipPositionMapping.push(ShipPositionMapping({
                shipLength: shipSizes[i],
                direction: generateRandomDirection(),
                axisX: 0,
                axisY: 0,
                state: ShipState.Intact
            }));
        }
    }

    function getShipPosition(uint8 index) external view returns (ShipPositionMapping memory) {
        return shipPositionMapping[index];
    }

    // generate a random ship direction
    function generateRandomDirection() private view returns (ShipDirection) {
        uint8 randomValue = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao))) % 2);
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
        axisX = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, shipLength, direction))) % gridSize);
        axisY = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, shipLength, direction, axisX))) % gridSize);

        // Adjust X and Y coordinates based on ship length and direction to ensure the entire ship fits within the grid
        if (direction == ShipDirection.Horizontal) {
            // Check if the ship goes out of bounds on the X-axis
            while (axisX + shipLength > gridSize) {
                axisX = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, shipLength, direction, axisX))) % gridSize);
            }
        } else if (direction == ShipDirection.Vertical) {
            // Check if the ship goes out of bounds on the Y-axis
            while (axisY + shipLength > gridSize) {
                axisY = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, shipLength, direction, axisY))) % gridSize);
            }
        }

        return (axisX, axisY);
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
            assembly {
                // Load the 32 bytes word from memory with the address on the lower 20 bytes, and mask those.
                sender := and(mload(add(array, index)), 0xffffffffffffffffffffffffffffffffffffffff)
            }
        } else {
            return msg.sender;
        }
    }

     function getShipTypeFromIndex(uint8 _index) public view returns (uint8){
        if (_index >= 0 && _index < gridDimensionN) {
            // Ship length is from 1 to n-1 (index+1) for gridDimensionN = 10
            return _index + 1;
        } else {
            return 0; // 0 represents None
        }
     }
     
     
    /*function getShipInxesFromShipLength(uint8 _shipLength) external view returns (uint8[] memory) {
        return shipIndexes[_shipLength];
    }*/

    function getBytes32FromBytes(bytes memory value, uint index) public pure returns(bytes32){
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

    // check the logic behind this function
    /*function getPositionsOccupiedByAllShips() external view returns (uint8[] memory) {
        uint8[] memory allShipPositions = new uint8[](gridDimensionN - 1);

        uint8 currentIndex = 0;
        for (uint8 i = 0; i < shipSizes.length; i++) {
            ShipPosition memory shipPos = shipPositionMapping[shipSizes[i]];
            uint8 axisX = shipPos.axisX;
            uint8 axisY = shipPos.axisY;
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
    }*/

    /*function getSlice(uint256 begin, uint256 end, string memory text) public pure returns (string memory) {
        bytes memory a = new bytes(end - begin + 1);
        for (uint i = 0; i <= end - begin; i++) {
            a[i] = bytes(text)[i + begin - 1];
        }
        return string(a);
    }*/

    /*function getShipPosition(uint8 positionKey) external view returns (ShipPosition memory) {
        return shipPositionMapping[positionKey];
    }*/

    /*function getOrderedPositionsAndAxis(string memory positions) external view returns (uint16[] memory, uint8[] memory, uint8[] memory) {
        uint8[] memory shipCounts = new uint8[](gridDimensionN - 1);
        uint16[] memory orderedPositions = new uint16[](gridDimensionN - 1);
        uint8[] memory axisX = new uint8[](gridDimensionN - 1);
        uint8[] memory axisY = new uint8[](gridDimensionN - 1);

        for (uint8 i = 0; i < gridDimensionN - 1; i++) {
            axisX[i] = 0;
            axisY[i] = 0;
        }

        uint8 currentIndex = 0;
        for (uint16 i = 0; i < 400; i += 4) {
            string memory shipPositionKey = getSlice(i + 1, i + 2, positions);
            ShipPosition memory shipPosition = getShipPosition(shipPositionKey);

            if (shipPosition.shipLength >= 1 && shipPosition.shipLength <= sumOfShipSizes - 1) {
                if (axisX[shipPosition.shipLength - 1] == 0) {
                    axisX[shipPosition.shipLength - 1] = generateRandomAxis(shipPosition.shipLength, shipPosition.direction, true);
                    axisY[shipPosition.shipLength - 1] = generateRandomAxis(shipPosition.shipLength, shipPosition.direction, false);
                }
                orderedPositions[shipCounts[shipPosition.shipLength - 1]] = (i / 4) + 1;
                shipCounts[shipPosition.shipLength - 1]++;
            }
        }

        return (orderedPositions, axisX, axisY);
    }*/

     

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
