local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

local function inj_FSBasemission_new(mission, superFunc, ...)
	local self = superFunc(mission, ...)
	self.destructibleMapObjectSystem = DestructibleMapObjectSystem.new(self, self:getIsServer())
	self.treeMarkerSystem = TreeMarkerSystem.new(self, self:getIsServer())

	return self
end

FSBaseMission.new = Utils.overwrittenFunction(FSBaseMission.new, inj_FSBasemission_new)

local function postFSBasemissionDelete(self)
	self.destructibleMapObjectSystem:delete()
	self.treeMarkerSystem:delete()
end

FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, postFSBasemissionDelete)

local function postFSBasemissionInitTerrain(self, terrainId, filename)
	self.treeMarkerSystem:initTerrain(terrainId, filename)
end

FSBaseMission.initTerrain = Utils.appendedFunction(FSBaseMission.initTerrain, postFSBasemissionInitTerrain)

local function postSendInitialClientState(self, connection, user, farm)
	self.destructibleMapObjectSystem:onClientJoined(connection)
	self.treeMarkerSystem:onClientJoined(connection)
end

FSBaseMission.sendInitialClientState = Utils.appendedFunction(FSBaseMission.sendInitialClientState, postSendInitialClientState)
