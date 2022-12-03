local modDirectory = g_currentModDirectory
local modName = g_currentModName
local sourceFiles = {
	"src/events/FSMStateEvent.lua",
	"src/events/SuperCupStartEvent.lua",
	"src/events/SuperCupStopEvent.lua",
	"src/events/SuperCupDriverEvent.lua",
	"src/events/SuperCupCheckPointEvent.lua",
	"src/events/SuperCupPenaltyEvent.lua",
	"src/events/SuperCupSeeSawEvent.lua",
	"src/Timer.lua",
	"src/Queue.lua",
	"src/stateMachine/states/AbstractState.lua",
	"src/stateMachine/states/StartState.lua",
	"src/stateMachine/states/RunState.lua",
	"src/stateMachine/states/FinishState.lua",
	"src/stateMachine/states/SetupState.lua",
	"src/stateMachine/StateEngine.lua",
	"src/stateMachine/FSM.lua",
	"src/SuperCupUtil.lua",
	"src/SuperCup.lua",
	"src/SuperCupActivatable.lua",
	"src/gui/hud/SuperCupHUD.lua",
	"src/objects/Seesaw.lua",
	"src/objects/TrafficLight.lua",
	"src/objects/Cone.lua",
	"src/objects/ConeHandler.lua",
	"src/objects/Checkpoint.lua",
	"src/objects/ActionRequiredCheckpoint.lua",
	"src/checkpointActions/CheckpointAction.lua",
	"src/checkpointActions/ObjectLowerAction.lua",
	"src/checkpointActions/ParkAction.lua",
	"src/checkpointActions/PickupAction.lua",
	"src/checkpointActions/BalanceSeesawAction.lua"
}

for _, file in ipairs(sourceFiles) do
	source(Utils.getFilename(file, modDirectory))
end

local function createPlayer(mission, superFunc, connection, isOwner, farmId, userId)
	superFunc(mission, connection, isOwner, farmId, userId)

	local player = g_currentMission:getPlayerByConnection(connection)

	if g_currentMission.userIdToPlayer == nil then
		g_currentMission.userIdToPlayer = {}
	end

	g_currentMission.userIdToPlayer[userId] = player
end

local function vehicleLeaveEvent_run(event, superFunc, connection)
	superFunc(event, connection)

	if not connection:getIsServer() and event.object ~= nil then
		local object = event.object

		if object.spec_superCupVehicle ~= nil then
			local spec = object.spec_superCupVehicle

			if spec.superCupObject ~= nil then
				spec.superCupObject.spec_superCup.superCup:stopSuperCup()
			end
		end
	end
end

local function setMirrorVisible(vehicle, superFunc, visible)
	local spec = vehicle.spec_enterable

	if spec.activeCamera == nil then
		return
	end

	return superFunc(vehicle, visible)
end

Enterable.setMirrorVisible = Utils.overwrittenFunction(Enterable.setMirrorVisible, setMirrorVisible)
VehicleLeaveEvent.run = Utils.overwrittenFunction(VehicleLeaveEvent.run, vehicleLeaveEvent_run)
FSBaseMission.createPlayer = Utils.overwrittenFunction(FSBaseMission.createPlayer, createPlayer)
