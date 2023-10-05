const BattleshipLogic = artifacts.require("BattleshipStorage");
const IntBattleshipStruct =artifacts.require("IntBattleshipStruct");
const ShipDirection = IntBattleshipStruct.ShipDirection;

contract("BattleshipLogic", accounts => {
    let battleshipLogicInstance;
    let WrongIndexErrorMessage = "Ships don't follow the right index";
    let noShipErrorMessage = "Ship Type must be of Type None";
    let player = "0x1a4033777e0eC8aF319418a4AC1A745b0A06E568";

    // Positions for player one and two
    let playerPositions = [
        { shipLength: 1, axisX: 1, axisY: 1, direction: ShipDirection.Horizontal },
        { shipLength: 2, axisX: 2, axisY: 2, direction: ShipDirection.Vertical }
    ];

    before(async () => {
        battleshipLogicInstance = await BattleshipLogic.deployed();
    });

    it("Should Verify Ship Index", async () => {
        let shipLength;
        try {
            shipLength = await battleshipLogicInstance.getShipLenghtFromIndex(0);
            assert.equal(
                shipLength.valueOf(),
                1,
                WrongIndexErrorMessage
            );
    
            shipLength = await battleshipLogicInstance.getShipLenghtFromIndex(1);
            assert.equal(
                shipLength.valueOf(),
                2,
                WrongIndexErrorMessage
            );
        } catch (error) {
            assert.fail(error);
        }
    });
    
    it("Should verify that Invalid Index returns No ship", async () => {
    
        try {
            const shipLength = await battleshipLogicInstance.getShipLenghtFromIndex(17);
            assert.equal(
                shipLength.valueOf(),
                0,
                noShipErrorMessage
            );
        } catch (error) {
            assert.fail(error);
        }
    });

    it("Should Verify Ship Positions on X and Y Axis", async () => {
        // Convert the player positions objects to individual arguments
        const playerShipLengths = playerPositions.map(ship => ship.shipLength);
        const playerAxisXs = playerPositions.map(ship => ship.axisX);
        const playerAxisYs = playerPositions.map(ship => ship.axisY);
        const playerDirections = playerPositions.map(ship => ship.direction);

        // Set ship positions for player one
        await battleshipLogicInstance.setShipPositions(playerShipLengths,
            playerAxisXs, playerAxisYs, playerDirections, player);

         /// Verify ship positions for player one
            for (let i = 0; i < playerPositions.length; i++) {
                const expectedPosition = { axisX: playerPositions[i].axisX, axisY: playerPositions[i].axisY };
                const actualPosition = await battleshipLogicInstance.getShipPositionByAxis(
                    player, expectedPosition.axisX, expectedPosition.axisY
                );
 
             assert.equal(
                 actualPosition.axisX, expectedPosition.axisX,
                 "Ship position X doesn't match the expected position"
             );
             assert.equal(
                 actualPosition.axisY, expectedPosition.axisY,
                 "Ship position Y doesn't match the expected position"
             );
         }
    });
});