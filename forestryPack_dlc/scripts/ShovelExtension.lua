local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

local modName = g_currentModName
local mapName = modName .. ".MapForest"
local oldShovel = Shovel.getCanShovelAtPosition

function Shovel:getCanShovelAtPosition(shovelNode)
	local ret = oldShovel(self, shovelNode)

	if g_currentMission.missionInfo.mapId == mapName and shovelNode ~= nil then
		local sx, _, sz = localToWorld(shovelNode.node, -shovelNode.width * 0.5, 0, 0)
		local ex, _, ez = localToWorld(shovelNode.node, shovelNode.width * 0.5, 0, 0)
		local targetPosX = -878
		local targetPosZ = -307
		local maxDistance = 20

		if MathUtil.vector2Length(targetPosX - sx, targetPosZ - sz) <= maxDistance and MathUtil.vector2Length(targetPosX - ex, targetPosZ - ez) <= maxDistance then
			return true
		end
	end

	return ret
end
