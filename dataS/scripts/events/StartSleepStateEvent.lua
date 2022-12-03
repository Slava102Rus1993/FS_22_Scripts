StartSleepStateEvent = {}
local StartSleepStateEvent_mt = Class(StartSleepStateEvent, Event)

InitStaticEventClass(StartSleepStateEvent, "StartSleepStateEvent", EventIds.EVENT_SLEEP_START)

function StartSleepStateEvent.emptyNew()
	local self = Event.new(StartSleepStateEvent_mt)

	return self
end

function StartSleepStateEvent.new(targetTime)
	local self = StartSleepStateEvent.emptyNew()
	self.targetTime = targetTime

	return self
end

function StartSleepStateEvent:readStream(streamId, connection)
	assert(connection:getIsServer(), "StartSleepStateEvent is a server to client only event")

	self.targetTime = streamReadInt32(streamId)

	self:run(connection)
end

function StartSleepStateEvent:writeStream(streamId, connection)
	streamWriteInt32(streamId, self.targetTime)
end

function StartSleepStateEvent:run(connection)
	if g_sleepManager ~= nil then
		g_sleepManager:startSleep(self.targetTime)
	end
end
