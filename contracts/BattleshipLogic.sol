// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma experimental ABIEncoderV2;

import "./interfaces/IntBattleshipStorage.sol";
import "./libs/MerkleProof.sol";

contract BattleshipLogic is IntBattleshipStruct {

    /**     TODO: check the code for possible mistake,
            and try if ShipPosition is compatible with other contracts**/
    uint8[] private shipSizes; // Array of ship lengths
    mapping(uint8 => uint8[]) private shipIndexes; // Mapping of shipLength to array of corresponding indexes
    mapping(uint8 => uint8) private shipFromIndex; // Mapping of shipLength index to shipLength value
    mapping(uint8 => ShipPosition) private shipPositionMapping; // Mapping of shipLength to shipPosition
    uint8 private sumOfShipSizes;
    uint8 private gridDimensionN;
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
        }
        sumOfShipSizes = gridDimensionN - 1;
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

    function initializeShipPositionMapping() private {
        for (uint8 i = 0; i < sumOfShipSizes; i++) {
            shipPositionMapping[shipSizes[i]] = ShipPosition(shipSizes[i], AxisType.X, ShipState.None);
        }
    }

    function getPositionsOccupiedByShips(uint8[] memory _ship, uint8[5] memory _startingPositions, AxisType[5] memory _axis) external view returns (uint8[] memory) {
        uint8[] memory combinedShipPositions = new uint8[](sumOfShipSizes);
        uint8[100] memory locationStatus;
        uint8 combinedShipPositionIndex = 0;

        for (uint8 i = 0; i < _startingPositions.length; i++) {
            uint8 shipLength = _ship[i];
            uint8 startingPosition = _startingPositions[i];
            AxisType axis = _axis[i];

            uint8 incrementer = axis == AxisType.X ? 1 : gridDimensionN;
            uint8 maxTile = startingPosition + (incrementer * (shipLength - 1));

            require(maxTile <= gridSquare && startingPosition >= 1, "Ship can not be placed outside the grid");

            if (axis == AxisType.X) {
                uint lowerFactor = startingPosition - 1;
                uint upperFactor = maxTile - 1;
                uint lowerLimitFactor = (lowerFactor - (lowerFactor % gridDimensionN)) / gridDimensionN;
                uint upperLimitFactor = (upperFactor - (upperFactor % gridDimensionN)) / gridDimensionN;
                require(lowerLimitFactor == upperLimitFactor, "Invalid Ship placement");
            }

            // Fill in the positions
            for (uint8 j = 0; j < shipLength; j++) {
                uint8 position = startingPosition + (j * incrementer);
                require(locationStatus[position] == 0, "Ships can not overlap");
                locationStatus[position] = 1;
                combinedShipPositions[combinedShipPositionIndex] = position;
                combinedShipPositionIndex++;
            }
        }
        return combinedShipPositions;
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
     
     
    function getShipInxesFromShipLenght(uint8 _shipLength) external view returns (uint8[] memory) {
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

    function getShipPosition(string memory positionKey) external view returns (ShipPosition memory) {
        return shipPositionMapping[stringToUint8(positionKey)];
    }
     
  
     /*function getOrderedpositionAndAxis(string memory positions) external view returns(uint16[] memory, AxisType[5] memory){
        AxisType[5] memory axis = [AxisType.None, AxisType.None, AxisType.None, AxisType.None, AxisType.None];
        uint16[] memory orderedPositions = new uint16[](17);



        uint8 destroyerCount = 0;
        uint8 submarineCount = 2;
        uint8 cruiserCount = 5;
        uint8 battleshipCount = 8;
        uint8 carrierCount = 12;

        ShipPosition memory shipPosition = ShipPosition(ShipType.None, AxisType.None);
        string memory shipPositionKey = "";

         for(uint16 i = 0; i < 400; i+=4)
         {

             shipPositionKey = getSlice(i+1, i+2, positions);
             shipPosition = shipPositionMapping[shipPositionKey];

             
             
             //Destroyer
             if(shipPosition.ship == ShipType.Destroyer) 
             {
                 if(axis[0] == AxisType.None) axis[0] = shipPosition.axis;
                 orderedPositions[destroyerCount] = (i/4) + 1;
                destroyerCount++;
             }
             
             //Submarine
             if(shipPosition.ship == ShipType.Submarine)
             {
                if(axis[1] == AxisType.None) axis[1] = shipPosition.axis;
                orderedPositions[submarineCount] = (i/4) + 1;
                submarineCount++;
             }
             
             //Cruiser
             if(shipPosition.ship == ShipType.Cruiser)
             {
                if(axis[2] == AxisType.None) axis[2] = shipPosition.axis;
                orderedPositions[cruiserCount] = (i/4) + 1;
                cruiserCount++;
             }
             
             //Battleship
             if(shipPosition.ship == ShipType.Battleship)
             {
                if(axis[3] == AxisType.None) axis[3] = shipPosition.axis;
                orderedPositions[battleshipCount] = (i/4) + 1;
                battleshipCount++;
             }
             
             //Carrier
             if(shipPosition.ship == ShipType.Carrier)
             {
                if(axis[4] == AxisType.None) axis[4] = shipPosition.axis;
                orderedPositions[carrierCount] = (i/4) + 1;
                carrierCount++;
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
