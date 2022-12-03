PlaceableWeatherStation = {
	prerequisitesPresent = function (specializations)
		return true
	end,
	registerEventListeners = function (placeableType)
		SpecializationUtil.registerEventListener(placeableType, "onLoad", PlaceableWeatherStation)
		SpecializationUtil.registerEventListener(placeableType, "onDelete", PlaceableWeatherStation)
		SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", PlaceableWeatherStation)
	end,
	registerXMLPaths = function (schema, basePath)
		schema:setXMLSpecializationType("WeatherStation")
		SoundManager.registerSampleXMLPaths(schema, basePath .. ".weatherStation.sounds", "idle")
		schema:setXMLSpecializationType()
	end,
	onLoad = function (self, savegame)
		local spec = self.spec_weatherStation

		if self.isClient then
			spec.sample = g_soundManager:loadSampleFromXML(self.xmlFile, "placeable.weatherStation.sounds", "idle", self.baseDirectory, self.components, 0, AudioGroup.ENVIRONMENT, self.i3dMappings, nil)
		end
	end,
	onDelete = function (self)
		g_currentMission.placeableSystem:removeWeatherStation(self)

		if self.isClient then
			local spec = self.spec_weatherStation

			if spec.sample ~= nil then
				g_soundManager:deleteSample(spec.sample)
			end
		end
	end,
	onFinalizePlacement = function (self)
		g_currentMission.placeableSystem:addWeatherStation(self)

		if self.isClient then
			local spec = self.spec_weatherStation

			if spec.sample ~= nil then
				g_soundManager:playSample(spec.sample)
			end
		end
	end
}
