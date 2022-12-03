Timer = {}
local Timer_mt = Class(Timer)

function Timer:new(delay, actionListener, hostObject)
	local self = setmetatable({}, Timer_mt)
	self.delay = delay
	self.initialDelay = delay
	self.elapsedDelay = delay
	self.running = false
	self.repeats = false
	self.isStopWatch = false
	self.actionListeners = {}

	SuperCupUtil.addToListIfNotExists(actionListener, self.actionListeners)

	self.hostObject = hostObject or g_currentMission

	assert(self.hostObject.addUpdateable ~= nil, "Host object does not have the addUpdateable function!")
	assert(self.hostObject.removeUpdateable ~= nil, "Host object does not have the removeUpdateable function!")

	return self
end

function Timer.schedule(delay, actionListener)
	local t = Timer:new(delay, actionListener)

	t:start()

	return t
end

function Timer:delete()
	self:clear()
end

function Timer:clear()
	self.running = false
	self.elapsedDelay = 0

	self.hostObject:removeUpdateable(self)
end

function Timer:getDelay()
	return self.delay
end

function Timer:setDelay(delay)
	self.delay = delay
end

function Timer:isRepeats()
	return self.repeats
end

function Timer:setIsRepeats(isRepeats)
	self.repeats = isRepeats
end

function Timer:setIsStopWatch(isStopWatch)
	self.isStopWatch = isStopWatch

	self:setDelay(0)
end

function Timer:start()
	self.hostObject:addUpdateable(self)

	self.running = true
	self.elapsedDelay = self.delay
end

function Timer:stop()
	self.hostObject:removeUpdateable(self)

	self.running = false
end

function Timer:restart()
	self:stop()
	self:start()
end

function Timer:fire()
	self:clear()

	for _, actionListener in ipairs(self.actionListeners) do
		actionListener()
	end
end

function Timer:isRunning()
	return self.running
end

function Timer:getElapsedTime()
	return self.elapsedDelay
end

function Timer:update(dt)
	if self.running then
		if self.isStopWatch then
			self.elapsedDelay = self.elapsedDelay + dt
		else
			self.elapsedDelay = self.elapsedDelay - dt

			if self.elapsedDelay <= 0 then
				self:fire()

				if self.repeats then
					self:restart()
				end
			end
		end
	end
end

function Timer:addActionListener(actionListener)
	SuperCupUtil.addToListIfNotExists(actionListener, self.actionListeners)
end

function Timer:removeActionListener(actionListener)
	table.removeElement(self.actionListeners, actionListener)
end

function Timer:getActionListeners()
	return self.actionListeners
end
