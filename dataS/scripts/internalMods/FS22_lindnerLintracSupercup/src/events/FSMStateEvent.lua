FSMStateEvent = {}
local FSMStateEvent_mt = Class(FSMStateEvent, Event)

InitEventClass(FSMStateEvent, "FSMStateEvent")

function FSMStateEvent.emptyNew()
	local self = Event.new(FSMStateEvent_mt)

	return self
end

function FSMStateEvent.new(object, type, stateId, params)
	local self = FSMStateEvent.emptyNew()
	self.object = object
	self.type = type
	self.stateId = stateId
	self.params = params or {}

	return self
end

function FSMStateEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteUIntN(streamId, self.type, 2)

	if self.type ~= FSM.EVENT_UPDATE then
		streamWriteUInt8(streamId, self.stateId)
		streamWriteUInt8(streamId, #self.params)

		for _, param in ipairs(self.params) do
			assert(type(param) == "number")
			streamWriteInt32(streamId, param)
		end
	end
end

function FSMStateEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.type = streamReadUIntN(streamId, 2)

	if self.type ~= FSM.EVENT_UPDATE then
		self.stateId = streamReadUInt8(streamId)
		local numOfParams = streamReadUInt8(streamId)

		if numOfParams > 0 then
			self.params = {}

			for i = 1, numOfParams do
				table.insert(self.params, streamReadInt32(streamId))
			end
		else
			self.params = {}
		end
	end

	self:run(connection)
end

function FSMStateEvent:run(connection)
	self.object.spec_superCup.superCup.stateMachine:run(self.type, self.stateId, self.params, true)
end
