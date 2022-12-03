SuperCupActivatable = {}
local SuperCupActivatable_mt = Class(SuperCupActivatable)

function SuperCupActivatable:new(superCup)
	local self = {}

	setmetatable(self, SuperCupActivatable_mt)

	self.superCup = superCup
	self.activateText = "unknown"

	return self
end

function SuperCupActivatable:getIsActivatable()
	if self.superCup.stateMachine:isInState(SuperCup.STATES.RUN) then
		return false
	end

	self:updateActivateText()

	return true
end

function SuperCupActivatable:run()
	self.superCup:setIsSuperCupStarted(not self.superCup.started)
	self:updateActivateText()
end

function SuperCupActivatable:drawActivate()
end

function SuperCupActivatable:updateActivateText()
	local key = self.superCup.started and "action_stopSuperCup" or "action_startSuperCup"
	self.activateText = g_i18n:getText(key)
end
