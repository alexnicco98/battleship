// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma experimental ABIEncoderV2;

contract BattleshipMigrations {
    address public owner = msg.sender; // address of the contract owner
    uint256 public lastCompletedMigration; // value of the last completed migration

    // restricts access to certain functions only to the contract owner
    modifier restricted() {
        require(msg.sender == owner, "Restricted to contract owner");
        _;
    }

    // Sets the value of lastCompletedMigration
    function setCompletedMigration(uint256 completed) external restricted {
        lastCompletedMigration = completed;
    }
}
