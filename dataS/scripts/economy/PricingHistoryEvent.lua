PricingHistoryEvent = {}
local PricingHistoryEvent_mt = Class(PricingHistoryEvent, Event)

InitStaticEventClass(PricingHistoryEvent, "PricingHistoryEvent", EventIds.EVENT_PRICING_HISTORY)

function PricingHistoryEvent.emptyNew()
	return Event.new(PricingHistoryEvent_mt)
end

function PricingHistoryEvent.new(period)
	local self = PricingHistoryEvent.emptyNew()
	self.period = period

	return self
end

function PricingHistoryEvent:readStream(streamId, connection)
	self.period = streamReadUIntN(streamId, 4)
	local fillTypes = g_fillTypeManager:getFillTypes()

	for i = 1, #fillTypes do
		fillTypes[i].economy.history[self.period] = streamReadInt32(streamId) / 1000
	end
end

function PricingHistoryEvent:writeStream(streamId, connection)
	streamWriteUIntN(streamId, self.period, 4)

	local fillTypes = g_fillTypeManager:getFillTypes()

	for i = 1, #fillTypes do
		streamWriteInt32(streamId, fillTypes[i].economy.history[self.period] * 1000)
	end
end

function PricingHistoryEvent:run(connection)
end
