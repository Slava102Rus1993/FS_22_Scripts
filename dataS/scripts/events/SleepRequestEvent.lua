SleepRequestEvent = {}
local SleepRequestEvent_mt = Class(SleepRequestEvent, Event)

InitStaticEventClass(SleepRequestEvent, "SleepRequestEvent", EventIds.EVENT_SLEEP_REQUEST)

function SleepRequestEvent.emptyNew()
	local self = Event.new(SleepRequestEvent_mt)

	return self
end

function SleepRequestEvent.new(userId, targetTime)
	local self = SleepRequestEvent.emptyNew()
	self.userId = userId
	self.targetTime = targetTime

	return self
end

function SleepRequestEvent:readStream(streamId, connection)
	self.userId = streamReadInt8(streamId)
	self.targetTime = streamReadInt32(streamId)

	self:run(connection)
end

function SleepRequestEvent:writeStream(streamId, connection)
	streamWriteInt8(streamId, self.userId)
	streamWriteInt32(streamId, self.targetTime)
end

function SleepRequestEvent:run(connection)
	if g_sleepManager ~= nil then
		if connection:getIsServer() then
			g_sleepManager:onSleepRequest(self.userId, self.targetTime)
		else
			g_sleepManager:startSleepRequest(self.userId, self.targetTime)
		end
	end
end
