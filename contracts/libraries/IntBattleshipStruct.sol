// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;
pragma experimental ABIEncoderV2;

library IntBattleshipStruct {

    enum GamePhase {None, Placement, Shooting, Gameover} // phase of the game
    enum ShipState {None, Intact, Damaged, Sunk } // condition of the ship
    enum ShipDirection {None, Vertical, Horizontal} // ship direction

    struct ShipPosition {
        uint8 shipLength;
        uint8 axisX;
        uint8 axisY;
        ShipDirection direction;
        ShipState state;
    }
    

    struct BattleModel {
        uint256 stake; // Ethers was staked for this battle
        address host; // Address of the host player
        address client; // Address of the client connected
        address turn; // Address indicating whose turn it is to play next
        bool isCompleted; // Battle has been completed
        bool opponentStakeRefundable; // Mark the opponent's stake as refundable
        bool clientStakeFrozen; // The client has expired his time to play
        bool hostStakeFrozen; // The host has expired his time to play
        address winner; // Address of the winning player;
        GamePhase gamePhase; // The game phase
        uint256 maxTimeForPlayerDelay; // If a player does not play after this time elapses,
                                       // then the contract will freeze the stake value of the player
                                       // and the other will obtain the ammount
        uint256 createdAt; // Time Created
    }

    struct PlayerModel {
        ShipPosition[] shipPositions; // Array of ship positions
        uint8[] leafIndexX; // for each shipPosition I save the leaf index X
        uint8[] leafIndexY; // for each shipPosition I save the leaf index Y
        uint8[] leafIndexShipPosition; // correspond to the shipPosition relative
                                         // to the leafIndexX[i] and leafIndexY[i]
        bytes32[][] leaves;  // Array of Merkle tree leaves
    }

    struct GamePhaseDetail {
        uint256 stake;
        uint256 penaltyAmount;
        GamePhase gamePhase;
        uint256 maxTimeForPlayerToPlay;
    }

    struct LobbyModel {
        bool isOccupied; // Indicates whether or not there is an occupant in the lobby.
        address occupant; // Holds the address of the occupant
        bytes32 playerOneRootHash; // Holds the merkletree root of the player one
        bytes32 playerTwoRootHash; // Holds the merkletree root of the player two
    }
    
}

