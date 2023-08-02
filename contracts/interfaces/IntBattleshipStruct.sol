// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
pragma experimental ABIEncoderV2;

interface IntBattleshipStruct {

    enum PlayerType {None, Host, Client}
    enum ShipType {None, Destroyer, Submarine, Cruiser, Battleship, Carrier}
    enum AxisType {None, X, Y}
    enum GameMode {None, Regular, Intermediate, Professional}
    enum VerificationStatus {None, Unverified, Ok, Cheated}

    struct BattleModel {
        uint256 stake; // Determines how much ethers was staked for this battle
        address host; // Holds the address of the host captain
        address client; // Holds the address of the client captain
        uint256 startTime; // Battle start time
        address turn; // Address indicating whose turn it is to play next
        bool isCompleted; // Indicates whether or not the battle has been completed
        address winner; // Holds the address of the winning player;
        GameMode gameMode; // The game mode
        uint256 maxTimeForPlayerDelay; // If a captain does not play after this time elapses,
                                       // then the contract will do a random play for the captain and
                                       // then permit the next player to play. This will be done when the
                                       // next player decides to play.
        bool isRewardClaimed; // Determines if the reward has been claimed by the winner;
        uint256 claimTime; // Holds the time that the reward was claimed
        uint256 createdAt; // Time Created
        uint256 updatedAt; // Time last Updated
        bool leafVerificationPassed; // Determines if the winner of the battle has passed the Leaf Verification Test
        bool shipPositionVerificationPassed; // Determines if the winner has passed the ship position verification Test
    }

    struct PlayerModel {
        string name; // Short name (up to 32 bytes)
        uint256 matchesPlayed; // Total number of matches played
        uint256 wins; // Total number of wins
        uint256 losses; // Total number of losses
        bool isVerified; // Indicates whether or not the account of the captain has been set up
        uint256 numberOfGamesHosted; // Total number Of games hosted;
        uint256 numberOfGamesJoined; // Total number of Games Joined;
        uint256 totalStaking; // The total amount of money that has been staked
        uint256 totalEarning; // The total amount of money that has been won
        uint256 createdAt; // Date Last created;
        uint256 updatedAt; // Date last updated
    }

    struct GameModeDetail {
        uint256 stake;
        GameMode gameType;
        uint256 maxTimeForPlayerToPlay;
    }

    struct LobbyModel {
        bool isOccupied; // Indicates whether or not there is an occupant in the lobby.
        address occupant; // Holds the address of the occupant
        bytes32 positionRoot; // Holds the merkletree root of the player's positions
        string encryptedMerkleTree; // Holds the full merkle tree, encrypted with the user's private key.
    }

    struct BattleVerificationModel {
        uint256 battleId;
        bytes32 previousPositionLeaf;
        bytes previousPositionProof;
        uint8 attackingPosition;
        bytes[] proofs;
        bytes32[] leafs;
        uint8[] indexes;
    }

    struct AttackModel {
        address player;
        uint256 tiles;
    }

    struct ShipPosition {
        ShipType ship;
        AxisType axis;
    }
    
}
