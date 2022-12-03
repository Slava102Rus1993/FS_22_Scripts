FSM = {
	EVENT_TRANS = 0,
	EVENT_UPDATE = 1,
	ANY_STATE = -1
}
local FSM_mt = Class(FSM)

function FSM:new(object, initialState, states, custom_mt)
	local self = setmetatable({}, custom_mt or FSM_mt)
	self.object = object
	self.initialState = initialState
	self.state = initialState
	self.states = states or {}

	return self
end

function FSM:delete()
	if self.state ~= nil then
		self.state:delete()
	end

	self.state = nil
	self.states = {}
end

function FSM:run(type, toStateId, params, noEventSend)
	if type == FSM.EVENT_TRANS then
		self:transition(toStateId, params, noEventSend)
	elseif type == FSM.EVENT_UPDATE then
		self:requestStateUpdate(noEventSend)
	end
end

function FSM:transition(toStateId, params, noEventSend)
	assert(self.states[toStateId] ~= nil)

	if self.object.isServer and not noEventSend then
		g_server:broadcastEvent(FSMStateEvent.new(self.object, FSM.EVENT_TRANS, toStateId, params))
	end

	local nextState = self.states[toStateId]
	local fromState = self.state

	fromState:onExit()
	self:setCurrentState(nextState)
	nextState:onEnter(unpack(params or {}))
end

function FSM:requestStateUpdate(noEventSend)
	if self.object.isServer and not noEventSend then
		g_server:broadcastEvent(FSMStateEvent.new(self.object, FSM.EVENT_UPDATE))
	end

	local state = self:getCurrentState()

	if state.updateActions ~= nil then
		for _, action in ipairs(state.updateActions) do
			action(state)
		end
	end
end

function FSM:setCurrentState(state)
	self.state = state
end

function FSM:getCurrentState()
	return self.state
end

function FSM:isInState(id)
	return id == self.state.id
end

function FSM:setInitialState(state)
	self.initialState = state
end

function FSM:getInitialState()
	return self.initialState
end

function FSM:reset()
	local state = self:getInitialState()

	self:transition(state)
end

function FSM:setStates(states)
	self.states = states
end

function FSM:update(dt)
	self.state:onUpdate(dt)
end

function FSM:draw()
	self.state:onDraw()
end
