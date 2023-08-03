// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma experimental ABIEncoderV2;

import "./IntBattleshipStruct.sol";

interface IntBattleshipLogic is IntBattleshipStruct{

    function getSumOfShipSize() external view returns (uint8);
    function getGridDimensionN() external view returns (uint8);
    function setGridDimensionN(uint8 newValue) external;

    function msgSender() external view returns(address sender);

    function getPositionsOccupiedByAllShips() external view returns (uint8[] memory);

    function getShipTypeFromIndex(uint8 index) external view returns (uint8);

    function getShipInxesFromShipLength(uint8 shipLenght) external view returns (uint8[] memory);

    function getSlice(uint256 begin, uint256 end, string memory text) external pure returns (string memory);

    function getShipPosition(string memory positionKey) external view returns (ShipPosition memory);

    /*function getOrderedPositionsAndAxis(string memory positions) external pure returns (uint8[] memory, AxisType[5] memory);

    function checkEqualArray(uint8[] memory arr1, uint8[] memory arr2) external pure returns (bool);

    function getSliceOfBytesArray(bytes memory bytesArray, uint16 indexStart, uint16 indexStop) external pure returns (bytes memory);
    */
}
