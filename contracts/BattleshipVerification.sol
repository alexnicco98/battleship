// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
pragma abicoder v2;

import "./interfaces/IntBattleshipStorage.sol";
import "./libraries/IntBattleshipStruct.sol";
//import "./interfaces/IntBattleshipLogic.sol";

/**
 * @title Battle Verification Contract
 * @dev Handles the verification of Battleship game results.
 */
contract BattleshipVerification {
    IntBattleshipStorage dataStorage;
    //IntBattleshipLogic gameLogic;
    address payable owner;

    constructor(address _dataStorage) { //, address _gameLogic
        dataStorage = IntBattleshipStorage(_dataStorage);
        owner = payable(dataStorage.msgSender());
        //gameLogic = IntBattleshipLogic(_gameLogic);
    }

    event LeafVerificationComplete(uint256 _battleId, address _winner, bool _verificationResult);
    event ShipPositionVerificationComplete(uint256 _battleId, address _winner, bool _verificationResult);

    /**
     * @dev Verifies the Merkle Tree leafs for a completed battle.
     * @param _battleId The ID of the battle to verify.
     * @param _leafs The Merkle Tree leafs of the player's moves.
     * @param _proofs The Merkle Tree proofs of the player's moves.
     * @return isTreeValid Whether the Merkle Tree leafs are valid.
     */
    /*function verifyLeafs(uint256 _battleId, bytes32 _leafs, bytes32[] memory _proofs) public returns (bool) {
        BattleModel memory battle = dataStorage.getBattle(_battleId);
        address player = dataStorage.msgSender();
        bytes32 root = dataStorage.getMerkleTreeRootByBattleIdAndPlayer(_battleId, player);

        require(battle.isCompleted, "Battle is not yet completed");
        require(battle.winner == player, "Only the suspected winner can access this function");
        require(!battle.leafVerificationPassed, "Leaf verification has already been passed");

        bool isTreeValid = merkleProof.checkProofsOrdered(_proofs, root, _leafs);
        emit LeafVerificationComplete(_battleId, player, isTreeValid);

        if (isTreeValid) {
            battle.leafVerificationPassed = true;
            dataStorage.updateBattleById(_battleId, battle);
            dataStorage.setRevealedLeafsByBattleIdAndPlayer(_battleId, player, _leafs);
        }

        return isTreeValid;
    }*/

    /**
     * @dev Verifies the ship positions for a completed battle.
     * @param _battleId The ID of the battle to verify.
     * @return isPositionValid Whether the ship positions are valid.
     */
    /*function verifyShipPositions(uint256 _battleId) public returns (bool) {
        uint8 memory size = gameLogic.getGridDimensionN() - 1;
        BattleModel memory battle = dataStorage.getBattle(_battleId);
        address player = gameLogic.msgSender();
        string memory leafs = dataStorage.getRevealedLeafsByBattleIdAndPlayer(_battleId, player);

        require(battle.isCompleted, "Battle is not yet completed");
        require(battle.winner == player, "Only the suspected winner can access this function");
        require(battle.leafVerificationPassed, "Leaf verification must be passed first");
        require(!battle.shipPositionVerificationPassed, "Ship Positions Verification has already been passed");

        uint8 [] memory ships = new uint8[](size);
        uint8[] memory orderedPositions = new uint8[](size);
        uint8[] memory axisX = new uint8[](size);
        uint8[] memory axisY = new uint8[](size);

        
        (orderedPositions, axisX, axisY) = gameLogic.getOrderedPositionsAndAxis(leafs);
        uint8[5] memory startingPositions = [orderedPositions[0], orderedPositions[2], orderedPositions[5], orderedPositions[8], orderedPositions[12]];

        // TODO: change the getOrderedPositionsAndAxis function to work with the new implementation
        uint8[] memory calculatedPositions = gameLogic.getPositionsOccupiedByAllShips(ships, startingPositions, axis);
        bool isPositionValid = gameLogic.checkEqualArray(calculatedPositions, orderedPositions);
        emit ShipPositionVerificationComplete(_battleId, player, isPositionValid);

        if (isPositionValid) {
            battle.shipPositionVerificationPassed = true;
            dataStorage.updateBattleById(_battleId, battle);
        }

        return isPositionValid;
    }*/
}
