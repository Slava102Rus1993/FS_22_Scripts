StopSleepStateEvent = {}
local StopSleepStateEvent_mt = Class(StopSleepStateEvent, Event)

InitStaticEventClass(StopSleepStateEvent, "StopSleepStateEvent", EventIds.EVENT_SLEEP_STOP)

function StopSleepStateEvent.emptyNew()
	local self = Event.new(StopSleepStateEvent_mt)

	return self
end

function StopSleepStateEvent.new()
	local self = StopSleepStateEvent.emptyNew()

	return self
end

function StopSleepStateEvent:readStream(streamId, connection)
	assert(connection:getIsServer(), "StopSleepStateEvent is a server to client only event")
	self:run(connection)
end

function StopSleepStateEvent:writeStream(streamId, connection)
end

function StopSleepStateEvent:run(connection)
	if g_sleepManager ~= nil then
		g_sleepManager:stopSleep()
	end
end
