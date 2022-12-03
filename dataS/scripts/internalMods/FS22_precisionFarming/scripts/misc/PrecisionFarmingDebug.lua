PrecisionFarmingDebug = {
	MOD_NAME = g_currentModName
}
local PrecisionFarmingDebug_mt = Class(PrecisionFarmingDebug)

function PrecisionFarmingDebug.new(precisionFarming, customMt)
	local self = setmetatable({}, customMt or PrecisionFarmingDebug_mt)
	self.precisionFarming = precisionFarming

	addConsoleCommand("pfToggleGroundDebug", "Enables debug display of ground data", "toggleGroundDebug", self)

	return self
end

function PrecisionFarmingDebug:toggleGroundDebug()
	if self.groundDebugArea == nil then
		local nitrogenMap = self.precisionFarming.nitrogenMap
		local coverMap = self.precisionFarming.coverMap
		local pHMap = self.precisionFarming.pHMap
		local data = {}
		self.groundDebugArea = DebugBitVectorMap.new(50, 2, 0.01, 0.1)

		self.groundDebugArea:createWithCustomFunc(function (_, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
			local centerX = (startWorldX + widthWorldX + heightWorldX) / 3
			local centerZ = (startWorldZ + widthWorldZ + heightWorldZ) / 3
			data.valid = coverMap:getIsUncoveredAtBitVectorPos(centerX, centerZ, true)

			if data.valid then
				data.nLevel = nitrogenMap:getLevelAtWorldPos(centerX, centerZ)
				data.nOffsetIsLocked, data.nOffset = nitrogenMap:getNOffsetDataAtWorldPos(centerX, centerZ)
				data.phLevel = pHMap:getLevelAtWorldPos(centerX, centerZ)
			end

			return 1, 0
		end)
		self.groundDebugArea:setAdditionalDrawInfoFunc(function (_, x, z, area, totalArea)
			if data.valid then
				local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z) + 0.1
				local nLevelReal = nitrogenMap:getNitrogenValueFromInternalValue(data.nLevel)
				local phLevelReal = pHMap:getPhValueFromInternalValue(data.phLevel)

				Utils.renderTextAtWorldPosition(x, y, z, string.format("N: %dkg (off: %d%s)\npH: %.3f", nLevelReal, data.nOffset, data.nOffsetIsLocked and " locked" or "", phLevelReal), getCorrectTextSize(0.01), 0)
			end
		end)
		g_debugManager:addPermanentElement(self.groundDebugArea)

		return
	end

	g_debugManager:removePermanentElement(self.groundDebugArea)

	self.groundDebugArea = nil
end
