AdditionalFieldBuyInfoEvent = {}
local AdditionalFieldBuyInfoEvent_mt = Class(AdditionalFieldBuyInfoEvent, Event)

InitEventClass(AdditionalFieldBuyInfoEvent, "AdditionalFieldBuyInfoEvent")

function AdditionalFieldBuyInfoEvent:emptyNew()
	local self = Event.new(AdditionalFieldBuyInfoEvent_mt)

	return self
end

function AdditionalFieldBuyInfoEvent.new(farmlandId)
	local self = AdditionalFieldBuyInfoEvent:emptyNew()
	self.farmlandId = farmlandId

	return self
end

function AdditionalFieldBuyInfoEvent:readStream(streamId, connection)
	self.farmlandId = streamReadUIntN(streamId, g_farmlandManager.numberOfBits)
	local pfModule = g_precisionFarming

	if pfModule ~= nil and pfModule.additionalFieldBuyInfo ~= nil then
		pfModule.additionalFieldBuyInfo:readInfoFromStream(self.farmlandId, streamId, connection)
	end
end

function AdditionalFieldBuyInfoEvent:writeStream(streamId, connection)
	streamWriteUIntN(streamId, self.farmlandId, g_farmlandManager.numberOfBits)

	local pfModule = g_precisionFarming

	if pfModule ~= nil and pfModule.additionalFieldBuyInfo ~= nil then
		pfModule.additionalFieldBuyInfo:writeInfoToStream(self.farmlandId, streamId, connection)
	end
end
