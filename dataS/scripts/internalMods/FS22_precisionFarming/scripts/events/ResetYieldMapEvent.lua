ResetYieldMapEvent = {}
local ResetYieldMapEvent_mt = Class(ResetYieldMapEvent, Event)

InitEventClass(ResetYieldMapEvent, "ResetYieldMapEvent")

function ResetYieldMapEvent:emptyNew()
	local self = Event.new(ResetYieldMapEvent_mt)

	return self
end

function ResetYieldMapEvent.new(farmlandId)
	local self = ResetYieldMapEvent:emptyNew()
	self.farmlandId = farmlandId

	return self
end

function ResetYieldMapEvent:readStream(streamId, connection)
	self.farmlandId = streamReadUIntN(streamId, 8)

	self:run(connection)
end

function ResetYieldMapEvent:writeStream(streamId, connection)
	streamWriteUIntN(streamId, self.farmlandId, 8)
end

function ResetYieldMapEvent:run(connection)
	if not connection:getIsServer() and g_precisionFarming ~= nil and g_precisionFarming.yieldMap ~= nil then
		g_precisionFarming.yieldMap:resetFarmlandYieldArea(self.farmlandId)
		g_precisionFarming:updatePrecisionFarmingOverlays()
	end
end
