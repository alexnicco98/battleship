// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma experimental ABIEncoderV2;

import "./IntBattleshipStruct.sol";

interface IntBattleshipLogic is IntBattleshipStruct{

    struct ShipPositionMapping {
        uint8 shipLength;
        ShipDirection direction;
        uint8 axisX;
        uint8 axisY;
        ShipState state;
    }

    function getSumOfShipSize() external view returns (uint8);
    function getGridDimensionN() external view returns (uint8);
    function setGridDimensionN(uint8 newValue) external;

    function msgSender() external view returns(address sender);

    function getPositionsOccupiedByAllShips() 
    external view returns (uint8[] memory);

    function getShipTypeFromIndex(uint8 index) external view returns (uint8);

    /*function getShipInxesFromShipLength(uint8 shipLenght) 
    external view returns (uint8[] memory);*/

    //function getSlice(uint256 begin, uint256 end, string memory text) external view returns (string memory);

    function getShipPosition(uint8 positionKey) 
    external view returns (ShipPositionMapping memory);

    /*function checkProofOrdered(bytes memory proof, bytes32 root, 
    string memory hash, uint256 index) external returns (bool);
    
    function checkProofsOrdered(bytes[] memory proofs, bytes32 root, 
    string memory leafs) external returns (bool);*/

    /*function checkProof(bytes32[] memory proof, bytes32 root, bytes32 leaf) 
    external pure returns (bool);*/

    //function getOrderedPositionsAndAxis(string memory positions) external pure returns (uint8[] memory, AxisType[5] memory);

    /*function checkEqualArray(uint8[] memory arr1, uint8[] memory arr2) external pure returns (bool);

    function getSliceOfBytesArray(bytes memory bytesArray, uint16 indexStart, uint16 indexStop) external pure returns (bytes memory);
    */
}
