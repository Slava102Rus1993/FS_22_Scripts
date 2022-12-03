BeaconLightManager = {
	MASK_ALL = 4294967295.0,
	MODE = {}
}
BeaconLightManager.MODE.ROTATE_LEFT = 0
BeaconLightManager.MODE.ROTATE_RIGHT = 1
BeaconLightManager.MODE.BLINK = 2
BeaconLightManager.MODE.ROTATE_LEFT_RIGHT = 3
BeaconLightManager.MODE.DOUBLE_ROTATE_CROSS = 4
BeaconLightManager.MODE.DOUBLE_ROTATE_LEFT = 5
BeaconLightManager.MODE.DOUBLE_ROTATE_RIGHT = 6
BeaconLightManager.MODE.DOUBLE_BLINK_TRIPLE_WAIT = 7
local BeaconLightManager_mt = Class(BeaconLightManager, AbstractManager)

function BeaconLightManager.new(customMt)
	local self = setmetatable({}, customMt or BeaconLightManager_mt)
	self.nextBeaconLightId = 1
	self.beaconLights = {}
	self.maxNumBeaconLights = 1
	self.lastBrightnessScale = nil

	return self
end

function BeaconLightManager:getNumOfLights()
	return getNumOfBeaconLights()
end

function BeaconLightManager:activateBeaconLight(mode, numLEDs, rpm, brightness)
	if #self.beaconLights < self.maxNumBeaconLights then
		local mask = BeaconLightManager.MASK_ALL
		local brightnessScale = g_gameSettings:getValue(GameSettings.SETTING.REAL_BEACON_LIGHT_BRIGHTNESS)

		if brightnessScale > 0 then
			setBeaconLights(mask, mode, numLEDs, rpm, brightness * brightnessScale)
		end

		local id = self.nextBeaconLightId
		self.nextBeaconLightId = self.nextBeaconLightId + 1

		table.insert(self.beaconLights, {
			id = id,
			mask = mask,
			mode = mode,
			numLEDs = numLEDs,
			rpm = rpm,
			brightness = brightness,
			brightnessScale = brightnessScale
		})

		return id
	end

	return nil
end

function BeaconLightManager:deactivateBeaconLight(id)
	if id ~= nil then
		local brightnessScale = g_gameSettings:getValue(GameSettings.SETTING.REAL_BEACON_LIGHT_BRIGHTNESS)

		for k, beaconLight in ipairs(self.beaconLights) do
			if beaconLight.id == id then
				if brightnessScale > 0 then
					setBeaconLights(beaconLight.mask, 0, 0, 100, 0)
				end

				table.remove(self.beaconLights, k)

				break
			end
		end
	end
end

function BeaconLightManager:updateBeaconLights()
	if #self.beaconLights > 0 then
		local brightnessScale = g_gameSettings:getValue(GameSettings.SETTING.REAL_BEACON_LIGHT_BRIGHTNESS)

		for k, beaconLight in ipairs(self.beaconLights) do
			if brightnessScale > 0 then
				setBeaconLights(beaconLight.mask, beaconLight.mode, beaconLight.numLEDs, beaconLight.rpm, beaconLight.brightness * brightnessScale)

				beaconLight.brightnessScale = brightnessScale
			elseif brightnessScale == 0 and beaconLight.brightnessScale > 0 then
				setBeaconLights(beaconLight.mask, 0, 0, 100, 0)

				beaconLight.brightnessScale = 0
			end
		end
	end
end

function BeaconLightManager.getModeByName(modeName)
	if modeName ~= nil then
		modeName = modeName:upper()

		return BeaconLightManager.MODE[modeName]
	end

	return nil
end

function BeaconLightManager.registerXMLPaths(schema, baseKey)
	schema:register(XMLValueType.STRING, baseKey .. "#mode", "Real beacon light mode")
	schema:register(XMLValueType.FLOAT, baseKey .. "#rpm", "Real beacon rpm")
	schema:register(XMLValueType.FLOAT, baseKey .. "#numLEDScale", "Real beacon num led factor (0-1)")
	schema:register(XMLValueType.FLOAT, baseKey .. "#brightnessScale", "Real beacon brightness factor (0-1)")
end

function BeaconLightManager.loadDeviceFromXML(xmlFile, baseKey)
	local deviceModeName = xmlFile:getValue(baseKey .. "#mode")

	if deviceModeName ~= nil then
		local deviceMode = BeaconLightManager.getModeByName(deviceModeName)

		if deviceMode ~= nil then
			local device = {
				mode = deviceMode,
				rpm = xmlFile:getValue(baseKey .. "#rpm", 100),
				numLEDScale = xmlFile:getValue(baseKey .. "#numLEDScale", 1),
				brightnessScale = xmlFile:getValue(baseKey .. "#brightnessScale", 1)
			}

			return device
		end
	end

	return nil
end

g_beaconLightManager = BeaconLightManager.new()
