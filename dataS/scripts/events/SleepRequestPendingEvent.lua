SleepRequestPendingEvent = {}
local SleepRequestPendingEvent_mt = Class(SleepRequestPendingEvent, Event)

InitStaticEventClass(SleepRequestPendingEvent, "SleepRequestPendingEvent", EventIds.EVENT_SLEEP_REQUEST_PENDING)

function SleepRequestPendingEvent.emptyNew()
	local self = Event.new(SleepRequestPendingEvent_mt)

	return self
end

function SleepRequestPendingEvent.new()
	local self = SleepRequestPendingEvent.emptyNew()

	return self
end

function SleepRequestPendingEvent:readStream(streamId, connection)
	assert(connection:getIsServer(), "SleepRequestPendingEvent is a server to client only event")
	self:run(connection)
end

function SleepRequestPendingEvent:writeStream(streamId, connection)
end

function SleepRequestPendingEvent:run(connection)
	if g_sleepManager ~= nil then
		g_sleepManager:onSleepRequestPending()
	end
end
