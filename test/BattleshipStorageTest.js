const BattleshipStorage = artifacts.require("BattleshipStorage");
const IntBattleshipStruct =artifacts.require("IntBattleshipStruct");
/*const ShipType = IDataStorageSchema.ShipType;
const AxisType = IDataStorageSchema.AxisType;
const GamePhase = IDataStorageSchema.GamePhase;*/
const ShipDirection = IntBattleshipStruct.ShipDirection;
const ShipState = IntBattleshipStruct.ShipState;
const GamePhase = IntBattleshipStruct.GamePhase;

contract("BattleshipStorage", dataStorage=>{
    it("Should set game mode details", ()=>{
        let dataStorage;
        let gamePhase = GamePhase.Placement;
        let expectedResult = true; 

        const gamePhaseDetail = {
            stake: 2,
            gamePhase: gamePhase,
            maxTimeForPlayerToPlay: 10
        };
        return BattleshipStorage.deployed()
        .then(instance =>{
            dataStorage = instance;
            return instance.setGamePhaseDetails(gamePhase, gamePhaseDetail)            
        })
        .then(result=>{
            assert.equal(result.receipt.status, expectedResult, "Incorrect game mode");
        })
    });

    it("Should return correct game mode", ()=>{
        let dataStorage;
        let gamePhase = GamePhase.Shooting;

        return BattleshipStorage.deployed()
        .then(instance=>{
            dataStorage = instance;
            return instance.getGamePhaseDetails(gamePhase);
        })
        .then(result=>{
            assert.equal(result.gamePhase, gamePhase);
        })
    });

    it("Should set amount of time user last session lasted", ()=>{
        let dataStorage;
        let expectedResult = true;
        let battleId = 1000;
        let playTime = 600000;
        return BattleshipStorage.deployed()
        .then(instance=>{
            dataStorage = instance;
            return dataStorage.setLastPlayTimeByBattleId(battleId, playTime);
        })
        .then(result=>{
            assert.equal(result.receipt.status, expectedResult,expectedResult);
        })
    });

    it("Should get amount of time user last session lasted", ()=>{
        let dataStorage;
        let battleId = 1000;
        let playTime = 600000;
        return BattleshipStorage.deployed()
        .then(instance=>{
            dataStorage = instance;
            return dataStorage.getLastPlayTimeByBattleId(battleId);
        })
        .then(result=>{
            assert.equal(result.words[0],playTime);
        })
    });
});

