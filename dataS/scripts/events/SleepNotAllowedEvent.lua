SleepNotAllowedEvent = {}
local SleepNotAllowedEvent_mt = Class(SleepNotAllowedEvent, Event)

InitStaticEventClass(SleepNotAllowedEvent, "SleepNotAllowedEvent", EventIds.EVENT_SLEEP_ALLOWED)

function SleepNotAllowedEvent.emptyNew()
	local self = Event.new(SleepNotAllowedEvent_mt)

	return self
end

function SleepNotAllowedEvent.new()
	local self = SleepNotAllowedEvent.emptyNew()

	return self
end

function SleepNotAllowedEvent:readStream(streamId, connection)
	assert(connection:getIsServer(), "SleepNotAllowedEvent is a server to client only event")
	self:run(connection)
end

function SleepNotAllowedEvent:writeStream(streamId, connection)
end

function SleepNotAllowedEvent:run(connection)
	if g_sleepManager ~= nil then
		g_sleepManager:onSleepNotAllowed()
	end
end
