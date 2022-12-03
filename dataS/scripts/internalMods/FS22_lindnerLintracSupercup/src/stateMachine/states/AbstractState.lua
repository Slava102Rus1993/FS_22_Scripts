AbstractState = {}
local AbstractState_mt = Class(AbstractState)

function AbstractState:new(id, stateMachine, custom_mt)
	local self = setmetatable({}, custom_mt or AbstractState_mt)
	self.id = id
	self.stateMachine = stateMachine
	self.entryActions = {}
	self.exitActions = {}
	self.updateActions = {}

	return self
end

function AbstractState:delete()
	self.stateMachine = nil
	self.entryActions = {}
	self.exitActions = {}
	self.updateActions = {}
end

function AbstractState:getId()
	return self.id
end

function AbstractState:onEnter(...)
	for _, entryAction in ipairs(self.entryActions) do
		entryAction(self, ...)
	end
end

function AbstractState:onExit(...)
	for _, exitAction in ipairs(self.exitActions) do
		exitAction(self, ...)
	end
end

function AbstractState:onUpdate(dt)
end

function AbstractState:onDraw()
end

function AbstractState:addEntryAction(action)
	SuperCupUtil.addToListIfNotExists(action, self.entryActions)
end

function AbstractState:addExitAction(action)
	SuperCupUtil.addToListIfNotExists(action, self.exitActions)
end

function AbstractState:addUpdateAction(action)
	SuperCupUtil.addToListIfNotExists(action, self.updateActions)
end
