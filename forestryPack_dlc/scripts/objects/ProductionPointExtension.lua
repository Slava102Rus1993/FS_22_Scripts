local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

local function postSetOutputDistributionMode(self, outputFillTypeId, mode, noEventSend)
	if self.loadingStation ~= nil then
		for _, trigger in ipairs(self.loadingStation.loadTriggers) do
			if trigger.setIsActive ~= nil and trigger:getIsFillTypeSupported(outputFillTypeId) then
				trigger:setIsActive(mode == ProductionPoint.OUTPUT_MODE.KEEP)
			end
		end
	end
end

ProductionPoint.setOutputDistributionMode = Utils.appendedFunction(ProductionPoint.setOutputDistributionMode, postSetOutputDistributionMode)
