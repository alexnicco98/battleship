const BattleshipStorage = artifacts.require("BattleshipStorage");
const IntBattleshipStruct = artifacts.require("IntBattleshipStruct");
const ShipDirection = IntBattleshipStruct.ShipDirection;
const ShipState = IntBattleshipStruct.ShipState;
const GamePhase = IntBattleshipStruct.GamePhase;

contract("BattleshipStorage", dataStorage=>{
    let battleshipStorageInstance;

    before(async () => {
        battleshipStorageInstance = await BattleshipStorage.deployed();
    });

    it("Should set game mode details", async ()=>{
        let expectedResult = true; 

        let gamePhaseDetail = {
            stake: 2,
            penaltyAmount: 2,
            gamePhase: GamePhase.Placement,
            maxTimeForPlayerToPlay: 10
        };

        let result = await battleshipStorageInstance.setGamePhaseDetails(GamePhase.Placement, gamePhaseDetail)            
        
        assert.equal(result.receipt.status, expectedResult, "Incorrect game mode");

    });

    it("Should return correct game mode", async ()=>{
        let gamePhase = GamePhase.Shooting;

        let result = await battleshipStorageInstance.getGamePhaseDetails(gamePhase);
        assert.equal(result.gamePhase, gamePhase);
        
    });

    it("Should set amount of time user last session lasted", async ()=>{
        let expectedResult = true;
        let battleId = 1000;
        let playTime = 600000;
        let result = await battleshipStorageInstance.setLastPlayTimeByBattleId(battleId, playTime);
        assert.equal(result.receipt.status, expectedResult,expectedResult);
    });

    it("Should get amount of time user last session lasted", async ()=>{
        let battleId = 1000;
        let playTime = 600000;
        let result = await battleshipStorageInstance.getLastPlayTimeByBattleId(battleId);

        assert.equal(result.words[0],playTime);

    });
});

