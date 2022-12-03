local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

ExtendedTreePlanterCreateTreeEvent = {}
local ExtendedTreePlanterCreateTreeEvent_mt = Class(ExtendedTreePlanterCreateTreeEvent, Event)

InitEventClass(ExtendedTreePlanterCreateTreeEvent, "ExtendedTreePlanterCreateTreeEvent")

function ExtendedTreePlanterCreateTreeEvent.emptyNew()
	local self = Event.new(ExtendedTreePlanterCreateTreeEvent_mt)

	return self
end

function ExtendedTreePlanterCreateTreeEvent.new(object)
	local self = ExtendedTreePlanterCreateTreeEvent.emptyNew()
	self.object = object

	return self
end

function ExtendedTreePlanterCreateTreeEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)

	self:run(connection)
end

function ExtendedTreePlanterCreateTreeEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
end

function ExtendedTreePlanterCreateTreeEvent:run(connection)
	if not connection:getIsServer() then
		g_server:broadcastEvent(self, false, connection, self.object)
	end

	if self.object ~= nil and self.object:getIsSynchronized() then
		self.object:createTree(true)
	end
end

function ExtendedTreePlanterCreateTreeEvent.sendEvent(vehicle, noEventSend)
	if noEventSend == nil or noEventSend == false then
		if g_server ~= nil then
			g_server:broadcastEvent(ExtendedTreePlanterCreateTreeEvent.new(vehicle), nil, , vehicle)
		else
			g_client:getServerConnection():sendEvent(ExtendedTreePlanterCreateTreeEvent.new(vehicle))
		end
	end
end
