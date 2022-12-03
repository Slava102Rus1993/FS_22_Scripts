StateEngine = {}
local StateEngine_mt = Class(StateEngine)

function StateEngine:new(object)
	local self = setmetatable({}, StateEngine_mt)
	self.stateMachine = FSM:new(object)
	self.states = {}

	return self
end

function StateEngine:add(stateId, state, params)
	assert(self.states[stateId] == nil, "State " .. stateId .. " already exists!")

	self.states[stateId] = state:new(stateId, self.stateMachine, unpack(params or {}))

	return self
end

function StateEngine:addEntryAction(stateId, action)
	assert(self.states[stateId] ~= nil, "State must exist!")
	self.states[stateId]:addEntryAction(action)

	return self
end

function StateEngine:addExitAction(stateId, action)
	assert(self.states[stateId] ~= nil, "State must exist!")
	self.states[stateId]:addExitAction(action)

	return self
end

function StateEngine:addUpdateAction(stateId, action)
	assert(self.states[stateId] ~= nil, "State must exist!")
	self.states[stateId]:addUpdateAction(action)

	return self
end

function StateEngine:build()
	if #self.states == 0 then
		log("Please add states first!")

		return nil
	end

	self.stateMachine:setStates(self.states)

	local initialState = self.states[1]

	self.stateMachine:setInitialState(initialState)
	self.stateMachine:setCurrentState(initialState)

	return self.stateMachine
end
