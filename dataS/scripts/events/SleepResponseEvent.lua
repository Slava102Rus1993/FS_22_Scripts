SleepResponseEvent = {}
local SleepResponseEvent_mt = Class(SleepResponseEvent, Event)

InitStaticEventClass(SleepResponseEvent, "SleepResponseEvent", EventIds.EVENT_SLEEP_RESPONSE)

function SleepResponseEvent.emptyNew()
	local self = Event.new(SleepResponseEvent_mt)

	return self
end

function SleepResponseEvent.new(answer)
	local self = SleepResponseEvent.emptyNew()
	self.answer = answer

	return self
end

function SleepResponseEvent:readStream(streamId, connection)
	assert(not connection:getIsServer(), "SleepResponseEvent is a client to server only event")

	self.answer = streamReadBool(streamId)

	self:run(connection)
end

function SleepResponseEvent:writeStream(streamId, connection)
	streamWriteBool(streamId, self.answer)
end

function SleepResponseEvent:run(connection)
	if g_sleepManager ~= nil then
		g_sleepManager:onSleepResponse(connection, self.answer)
	end
end
