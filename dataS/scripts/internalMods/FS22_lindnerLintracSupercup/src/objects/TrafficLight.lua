TrafficLight = {
	STATES = {
		GREEN = 3,
		ORANGE = 2,
		RED = 1
	}
}
TrafficLight.COLOR_NAMES_TO_STATES = {
	RED = TrafficLight.STATES.RED,
	ORANGE = TrafficLight.STATES.ORANGE,
	GREEN = TrafficLight.STATES.GREEN
}
local TrafficLight_mt = Class(TrafficLight)

InitObjectClass(TrafficLight, "TrafficLight")

function TrafficLight.registerXMLPaths(schema, basePath)
	schema:register(XMLValueType.STRING, basePath .. ".lights(?)#color", "the cone state")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".lights(?).light(?)#node", "the light node")
end

function TrafficLight:new(nodeId, isServer, isClient)
	local self = setmetatable({}, TrafficLight_mt)
	self.nodeId = nodeId
	self.isServer = isServer
	self.isClient = isClient
	self.lightsPerState = {}

	registerObjectClassName(self, "TrafficLight")

	return self
end

function TrafficLight:delete()
	unregisterObjectClassName(self)
end

function TrafficLight:loadFromXML(xmlFile, baseKey, components, i3dMappings)
	local i = 0

	while true do
		local key = ("%s.trafficLight.lights(%d)"):format(baseKey, i)

		if not xmlFile:hasProperty(key) then
			break
		end

		local stateStr = xmlFile:getValue(key .. "#color", "RED")
		local state = TrafficLight.COLOR_NAMES_TO_STATES[stateStr]

		if state == nil then
			Logging.xmlWarning("Invalid state for traffic light!")

			break
		end

		local lights = {}

		if self:loadLightsFromXML(xmlFile, key, lights, components, i3dMappings) then
			if self.lightsPerState[state] == nil then
				self.lightsPerState[state] = {}
			end

			table.insert(self.lightsPerState[state], lights)
		end

		i = i + 1
	end
end

function TrafficLight:loadLightsFromXML(xmlFile, baseKey, lights, components, i3dMappings)
	local i = 0

	while true do
		local key = ("%s.light(%d)"):format(baseKey, i)

		if not xmlFile:hasProperty(key) then
			break
		end

		local node = xmlFile:getValue(key .. "#node", nil, components, i3dMappings)

		if node ~= nil then
			setVisibility(node, false)
			table.insert(lights, node)
		end

		i = i + 1
	end

	return true
end

function TrafficLight:reset()
	self:setState(TrafficLight.STATES.RED)
end

function TrafficLight:next()
	local newLightState = self.lightState + 1

	if TrafficLight.STATES.GREEN < newLightState then
		newLightState = TrafficLight.STATES.RED
	end

	self:setState(newLightState)
end

function TrafficLight:setState(state)
	local prevLightState = self.lightState
	local prevLights = self.lightsPerState[prevLightState]

	self:setLightsState(prevLights, false)

	local nextLights = self.lightsPerState[state]

	self:setLightsState(nextLights, true)

	self.lightState = state
end

function TrafficLight:setLightsState(lightGroup, isOn)
	if lightGroup ~= nil then
		for _, lights in ipairs(lightGroup) do
			for _, light in ipairs(lights) do
				setVisibility(light, isOn)
			end
		end
	end
end
