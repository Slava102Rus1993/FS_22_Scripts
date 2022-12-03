RTKStation = {
	prerequisitesPresent = function (specializations)
		return true
	end,
	registerFunctions = function (placeableType)
	end,
	registerOverwrittenFunctions = function (placeableType)
	end,
	registerEventListeners = function (placeableType)
		SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", RTKStation)
		SpecializationUtil.registerEventListener(placeableType, "onDelete", RTKStation)
	end,
	registerXMLPaths = function (schema, basePath)
	end,
	onFinalizePlacement = function (self, savegame)
		if g_precisionFarming ~= nil then
			g_precisionFarming.aiExtension:registerRTKStation(self)
		end
	end,
	onDelete = function (self)
		if g_precisionFarming ~= nil then
			g_precisionFarming.aiExtension:unregisterRTKStation(self)
		end
	end
}
