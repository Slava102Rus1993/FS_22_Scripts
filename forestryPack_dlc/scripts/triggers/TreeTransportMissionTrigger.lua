local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

TreeTransportMissionTrigger = {}
local TreeTransportMissionTrigger_mt = Class(TreeTransportMissionTrigger, WoodUnloadTrigger)

InitObjectClass(TreeTransportMissionTrigger, "TreeTransportMissionTrigger")

function TreeTransportMissionTrigger.new(isServer, isClient, customMt)
	local self = WoodUnloadTrigger.new(isServer, isClient, customMt or TreeTransportMissionTrigger_mt)

	return self
end

function TreeTransportMissionTrigger:onProcessedWood(nodeId, volume, fillType)
	if nodeId ~= nil and nodeId ~= 0 then
		local mission = g_missionManager:getMissionBySplitShape(nodeId)

		if mission ~= nil and mission.onTriggerProcessedWood ~= nil then
			mission:onTriggerProcessedWood(self, nodeId, volume, fillType)
		end
	end
end

function TreeTransportMissionTrigger:getNeedRaiseActive()
	return true
end
