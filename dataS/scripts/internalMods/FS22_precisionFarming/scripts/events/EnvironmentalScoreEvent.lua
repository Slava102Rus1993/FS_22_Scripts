EnvironmentalScoreEvent = {}
local EnvironmentalScoreEvent_mt = Class(EnvironmentalScoreEvent, Event)

InitEventClass(EnvironmentalScoreEvent, "EnvironmentalScoreEvent")

function EnvironmentalScoreEvent:emptyNew()
	local self = Event.new(EnvironmentalScoreEvent_mt)

	return self
end

function EnvironmentalScoreEvent.new(farmId)
	local self = EnvironmentalScoreEvent:emptyNew()
	self.farmId = farmId

	return self
end

function EnvironmentalScoreEvent:readStream(streamId, connection)
	self.farmId = streamReadUIntN(streamId, FarmManager.FARM_ID_SEND_NUM_BITS)
	local pfModule = g_precisionFarming

	if pfModule ~= nil and pfModule.environmentalScore ~= nil then
		pfModule.environmentalScore:readStream(streamId, connection, self.farmId)
	end
end

function EnvironmentalScoreEvent:writeStream(streamId, connection)
	streamWriteUIntN(streamId, self.farmId, FarmManager.FARM_ID_SEND_NUM_BITS)

	local pfModule = g_precisionFarming

	if pfModule ~= nil and pfModule.environmentalScore ~= nil then
		pfModule.environmentalScore:writeStream(streamId, connection, self.farmId)
	end
end
