SleepRequestDeniedEvent = {}
local SleepRequestDeniedEvent_mt = Class(SleepRequestDeniedEvent, Event)

InitStaticEventClass(SleepRequestDeniedEvent, "SleepRequestDeniedEvent", EventIds.EVENT_SLEEP_REQUEST_DENIED)

function SleepRequestDeniedEvent.emptyNew()
	local self = Event.new(SleepRequestDeniedEvent_mt)

	return self
end

function SleepRequestDeniedEvent.new(userId)
	local self = SleepRequestDeniedEvent.emptyNew()
	self.userId = userId or 0

	return self
end

function SleepRequestDeniedEvent:readStream(streamId, connection)
	assert(connection:getIsServer(), "SleepRequestDeniedEvent is a server to client only event")

	self.userId = streamReadInt32(streamId)

	self:run(connection)
end

function SleepRequestDeniedEvent:writeStream(streamId, connection)
	streamWriteInt32(streamId, self.userId)
end

function SleepRequestDeniedEvent:run(connection)
	if g_sleepManager ~= nil then
		g_sleepManager:onSleepRequestDenied(self.userId)
	end
end
