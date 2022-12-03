PricingHistoryInitialEvent = {}
local PricingHistoryInitialEvent_mt = Class(PricingHistoryInitialEvent, Event)

InitStaticEventClass(PricingHistoryInitialEvent, "PricingHistoryInitialEvent", EventIds.EVENT_PRICING_HISTORY_INIT)

function PricingHistoryInitialEvent.emptyNew()
	return Event.new(PricingHistoryInitialEvent_mt)
end

function PricingHistoryInitialEvent.new()
	local self = PricingHistoryInitialEvent.emptyNew()

	return self
end

function PricingHistoryInitialEvent:readStream(streamId, connection)
	local fillTypes = g_fillTypeManager:getFillTypes()

	for i = 1, #fillTypes do
		for period = 1, 12 do
			fillTypes[i].economy.history[period] = streamReadInt32(streamId) / 1000
		end
	end
end

function PricingHistoryInitialEvent:writeStream(streamId, connection)
	local fillTypes = g_fillTypeManager:getFillTypes()

	for i = 1, #fillTypes do
		for period = 1, 12 do
			streamWriteInt32(streamId, fillTypes[i].economy.history[period] * 1000)
		end
	end
end

function PricingHistoryInitialEvent:run(connection)
end
