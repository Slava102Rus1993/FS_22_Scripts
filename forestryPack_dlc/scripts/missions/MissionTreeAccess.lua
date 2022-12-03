local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

local function overwrittenIsCuttingAllowed(self, superFunc, x, y, z, shape)
	local isAllowed = g_missionManager:getIsShapeCutAllowed(shape, x, z, self.player.farmId)

	if isAllowed ~= nil then
		return isAllowed
	end

	if superFunc(self, x, y, z, shape) then
		return true
	end

	return false
end

Chainsaw.isCuttingAllowed = Utils.overwrittenFunction(Chainsaw.isCuttingAllowed, overwrittenIsCuttingAllowed)

local function overwrittenGetCanSplitShapeBeAccessed(self, superFunc, x, z, shape)
	local isAllowed = g_missionManager:getIsShapeCutAllowed(shape, x, z, self:getActiveFarm())

	if isAllowed ~= nil then
		return isAllowed
	end

	if superFunc(self, x, z) then
		return true
	end

	return false
end

WoodHarvester.getCanSplitShapeBeAccessed = Utils.overwrittenFunction(WoodHarvester.getCanSplitShapeBeAccessed, overwrittenGetCanSplitShapeBeAccessed)
