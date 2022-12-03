local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

TreeMarkerSystem = {
	MOD_DIRECTORY = g_currentModDirectory
}

g_xmlManager:addCreateSchemaFunction(function ()
	TreeMarkerSystem.xmlSchema = XMLSchema.new("treeMarkerSystem")
	TreeMarkerSystem.xmlSchemaSavegame = XMLSchema.new("treeMarkerSystem_savegame")
end)
g_xmlManager:addInitSchemaFunction(function ()
	local schema = TreeMarkerSystem.xmlSchema

	schema:register(XMLValueType.STRING, "treeMarkerTypes.treeMarkerType(?)#name", "Name of the treemarker")
	schema:register(XMLValueType.STRING, "treeMarkerTypes.treeMarkerType(?)#title", "Title of the treemarker")
	schema:register(XMLValueType.FLOAT, "treeMarkerTypes.treeMarkerType(?)#scale", "Scale of the marker")
	schema:register(XMLValueType.STRING, "treeMarkerTypes.treeMarkerType(?).texture#filename", "Filename of the custom shader texture")
	schema:register(XMLValueType.STRING, "treeMarkerTypes.treeMarkerType(?).icon#filename", "Filename of the hud icon")

	local schemaSave = TreeMarkerSystem.xmlSchemaSavegame

	schemaSave:register(XMLValueType.STRING, "treeMarkerSystem.treeMarkers.treeMarker(?)#type", "Treemarker type name")
	schemaSave:register(XMLValueType.BOOL, "treeMarkerSystem.treeMarkers.treeMarker(?)#isSplitShape", "Is treemarker on a splitshape or on a preplaced tree")
	schemaSave:register(XMLValueType.VECTOR_4, "treeMarkerSystem.treeMarkers.treeMarker(?)#color", "Treemarker color")
	schemaSave:register(XMLValueType.FLOAT, "treeMarkerSystem.treeMarkers.treeMarker(?)#scale", "Treemarker scale")
	schemaSave:register(XMLValueType.FLOAT, "treeMarkerSystem.treeMarkers.treeMarker(?)#posX", "Treemarker x position")
	schemaSave:register(XMLValueType.FLOAT, "treeMarkerSystem.treeMarkers.treeMarker(?)#posY", "Treemarker y position")
	schemaSave:register(XMLValueType.FLOAT, "treeMarkerSystem.treeMarkers.treeMarker(?)#rotY", "Treemarker rotation")
	schemaSave:register(XMLValueType.INT, "treeMarkerSystem.treeMarkers.treeMarker(?)#splitShapePart1", "Treemarker splitShapePart1")
	schemaSave:register(XMLValueType.INT, "treeMarkerSystem.treeMarkers.treeMarker(?)#splitShapePart2", "Treemarker splitShapePart2")
	schemaSave:register(XMLValueType.INT, "treeMarkerSystem.treeMarkers.treeMarker(?)#splitShapePart3", "Treemarker splitShapePart3")
end)

local TreeMarkerSystem_mt = Class(TreeMarkerSystem)

function TreeMarkerSystem.new(mission, isServer, customMt)
	local self = setmetatable({}, customMt or TreeMarkerSystem_mt)
	self.mission = mission
	self.isServer = isServer
	self.treeOverlay = nil
	self.treeMarkers = {}
	self.nameToTreeMarkerType = {}
	self.treeMarkerTypes = {}
	self.shaderParameter = "markerPosScaleRot"
	self.shaderParameterColor = "markerColorScale"
	self.shaderParameterMap = "mMarker"

	return self
end

function TreeMarkerSystem:delete()
	for _, treeMarker in ipairs(self.treeMarkerTypes) do
		treeMarker.iconOverlay:delete()
		delete(treeMarker.markerTexture)
	end

	if self.treeOverlay ~= nil then
		self.treeOverlay:delete()
	end
end

function TreeMarkerSystem:loadMapData(xmlFile, missionInfo, baseDirectory)
	local uiScale = g_gameSettings:getValue("uiScale")
	local width, height = getNormalizedScreenValues(80 * uiScale, 80 * uiScale)
	local filename = Utils.getFilename("shared/treeMarker/markerTree_icon.png", TreeMarkerSystem.MOD_DIRECTORY)
	local overlay = Overlay.new(filename, 0.5, 0.5, width, height)

	overlay:setAlignment(Overlay.ALIGN_VERTICAL_MIDDLE, Overlay.ALIGN_HORIZONTAL_CENTER)
	overlay:setColor(1, 1, 1, 0.3)

	self.treeOverlay = overlay
	local defaultFilename = Utils.getFilename("maps_treeMarkerTypes.xml", baseDirectory)

	self:loadTreeMarkerTypes(defaultFilename)

	local additionalMapTreeMarkerFilename = getXMLString(xmlFile, "map.treeMarkerTypes#filename")

	if additionalMapTreeMarkerFilename ~= nil then
		local _, mapBaseDirectory = Utils.getModNameAndBaseDirectory(getXMLFilename(xmlFile))
		local xmlFilename = Utils.getFilename(additionalMapTreeMarkerFilename, mapBaseDirectory)

		self:loadTreeMarkerTypes(xmlFilename)
	end
end

function TreeMarkerSystem:initTerrain(terrainId, filename)
	self.yWorldPosCompressionParams = NetworkUtil.createWorldPositionCompressionParams(1500, 0, 0.01)
	self.xzWorldPosCompressionParams = NetworkUtil.createWorldPositionCompressionParams(g_currentMission.terrainSize + 500, 0.5 * (g_currentMission.terrainSize + 500), 0.01)
	self.xTreePosCompressionParams = NetworkUtil.createWorldPositionCompressionParams(10, 0, 0.01)
	self.yTreePosCompressionParams = NetworkUtil.createWorldPositionCompressionParams(50, 0, 0.01)
end

function TreeMarkerSystem:loadTreeMarkerTypes(filename)
	local xmlFile = XMLFile.loadIfExists("treeMarker", filename, TreeMarkerSystem.xmlSchema)

	if xmlFile ~= nil then
		local modName, baseDirectory = Utils.getModNameAndBaseDirectory(filename)
		local customEnv = modName

		xmlFile:iterate("treeMarkerTypes.treeMarkerType", function (_, key)
			local name = xmlFile:getValue(key .. "#name")
			local title = xmlFile:getValue(key .. "#title")
			local scale = xmlFile:getValue(key .. "#scale")
			local textureFilename = xmlFile:getValue(key .. ".texture#filename")
			local iconFilename = xmlFile:getValue(key .. ".icon#filename")

			if name ~= nil then
				textureFilename = Utils.getFilename(textureFilename, baseDirectory)
				iconFilename = Utils.getFilename(iconFilename, baseDirectory)
				title = g_i18n:convertText(title, customEnv)

				self:registerTreeMarkerType(name, title, scale, textureFilename, iconFilename)
			end
		end)
		xmlFile:delete()
	end
end

function TreeMarkerSystem:registerTreeMarkerType(name, title, scale, markerFilename, iconFilename)
	if not ClassUtil.getIsValidIndexName(name) then
		Logging.warning("'%s' is not a valid name for a tree marker type!", tostring(name))

		return
	end

	name = string.upper(name)
	local treeMarkerType = self.nameToTreeMarkerType[name]
	local isNew = false

	if treeMarkerType == nil then
		treeMarkerType = {}
		self.nameToTreeMarkerType[name] = treeMarkerType

		table.insert(self.treeMarkerTypes, treeMarkerType)

		treeMarkerType.index = #self.treeMarkerTypes
		isNew = true
	end

	treeMarkerType.name = name
	treeMarkerType.title = title or treeMarkerType.title or "Unknown"
	treeMarkerType.scale = scale or treeMarkerType.scale or 0.4

	if markerFilename ~= nil then
		local markerTexture = createMaterialTextureFromFile(markerFilename, true, false)

		if markerTexture ~= 0 and markerTexture ~= nil then
			if treeMarkerType.markerTexture ~= nil then
				delete(treeMarkerType.markerTexture)
			end

			treeMarkerType.markerTexture = markerTexture
		end
	end

	if iconFilename ~= nil then
		local uiScale = g_gameSettings:getValue("uiScale")
		local width, height = getNormalizedScreenValues(80 * uiScale, 80 * uiScale)
		local overlay = Overlay.new(iconFilename, 0, 0, width, height)

		if overlay ~= nil then
			if treeMarkerType.iconOverlay ~= nil then
				treeMarkerType.iconOverlay:delete()
			end

			overlay:setAlignment(Overlay.ALIGN_VERTICAL_MIDDLE, Overlay.ALIGN_HORIZONTAL_CENTER)
			overlay:setPosition(0.5, 0.5)
			overlay:setColor(1, 1, 1, 0.3)

			treeMarkerType.iconOverlay = overlay
		end
	end
end

function TreeMarkerSystem:onClientJoined(connection)
	local treeMarkers = {}

	for splitShapeId, data in pairs(self.treeMarkers) do
		local treeMarker = {
			splitShapeId = data.splitShapeId,
			treeMarkerTypeIndex = data.treeMarkerTypeIndex,
			r = data.r,
			g = data.g,
			b = data.b,
			a = data.a,
			posX = data.posX,
			posY = data.posY,
			scale = data.scale,
			rotY = data.rotY
		}

		table.insert(treeMarkers, treeMarker)

		if #treeMarkers == 255 then
			connection:sendEvent(TreeMarkerEvent.new(treeMarkers))

			treeMarkers = {}
		end
	end

	if #treeMarkers > 0 then
		connection:sendEvent(TreeMarkerEvent.new(treeMarkers))
	end
end

function TreeMarkerSystem:saveToXMLFile(xmlPath, usedModNames)
	if xmlPath ~= nil then
		local xmlFile = XMLFile.create("TreeMarkerSystemSavegameXML", xmlPath, "treeMarkerSystem", TreeMarkerSystem.xmlSchemaSavegame)

		if xmlFile ~= nil then
			local i = 0

			for shapeId, treeMarker in pairs(self.treeMarkers) do
				if entityExists(shapeId) then
					local splitShapePart1, splitShapePart2, splitShapePart3 = getSaveableSplitShapeId(shapeId)

					if splitShapePart1 ~= 0 and splitShapePart1 ~= nil then
						local key = string.format("treeMarkerSystem.treeMarkers.treeMarker(%d)", i)

						xmlFile:setValue(key .. "#splitShapePart1", splitShapePart1)
						xmlFile:setValue(key .. "#splitShapePart2", splitShapePart2)
						xmlFile:setValue(key .. "#splitShapePart3", splitShapePart3)

						local treeMarkerType = self:getTreeMarkerTypeByIndex(treeMarker.treeMarkerTypeIndex)

						xmlFile:setValue(key .. "#type", treeMarkerType.name)
						xmlFile:setValue(key .. "#color", treeMarker.r, treeMarker.g, treeMarker.b, treeMarker.a)
						xmlFile:setValue(key .. "#scale", treeMarker.scale)
						xmlFile:setValue(key .. "#posX", treeMarker.posX)
						xmlFile:setValue(key .. "#posY", treeMarker.posY)
						xmlFile:setValue(key .. "#rotY", math.deg(treeMarker.rotY))

						i = i + 1
					end
				end
			end

			xmlFile:save()
			xmlFile:delete()
		end
	end
end

function TreeMarkerSystem:loadFromXMLFile(xmlPath)
	if xmlPath ~= nil then
		local xmlFile = XMLFile.loadIfExists("TreeMarkerSystemSavegameXML", xmlPath, TreeMarkerSystem.xmlSchemaSavegame)

		if xmlFile ~= nil then
			xmlFile:iterate("treeMarkerSystem.treeMarkers.treeMarker", function (_, key)
				local treeMarkerTypeName = xmlFile:getValue(key .. "#type")

				if treeMarkerTypeName ~= nil then
					local treeMarkerType = self:getTreeMarkerTypeByName(treeMarkerTypeName)

					if treeMarkerType ~= nil then
						local splitShapePart1 = xmlFile:getValue(key .. "#splitShapePart1")

						if splitShapePart1 ~= nil then
							local splitShapePart2 = xmlFile:getValue(key .. "#splitShapePart2")
							local splitShapePart3 = xmlFile:getValue(key .. "#splitShapePart3")
							local shapeId = getShapeFromSaveableSplitShapeId(splitShapePart1, splitShapePart2, splitShapePart3)

							if shapeId ~= nil and shapeId ~= 0 then
								local r, g, b, a = xmlFile:getValue(key .. "#color", {
									1,
									1,
									1,
									1
								}, false)
								local posX = xmlFile:getValue(key .. "#posX", 0)
								local posY = xmlFile:getValue(key .. "#posY", 0)
								local scale = xmlFile:getValue(key .. "#scale", 0.4)
								local rotY = math.rad(xmlFile:getValue(key .. "#rotY", 0))

								self:addTreeMarker(shapeId, treeMarkerType.index, r, g, b, a, posX, posY, scale, rotY)
							end
						end
					end
				end
			end)
			xmlFile:delete()
		end
	end
end

function TreeMarkerSystem:getTreeMarkerTypeByIndex(index)
	return self.treeMarkerTypes[index]
end

function TreeMarkerSystem:getTreeMarkerTypeByName(name)
	if not ClassUtil.getIsValidIndexName(name) then
		Logging.warning("'%s' is not a valid name for a tree marker type!", tostring(name))

		return nil
	end

	name = string.upper(name)

	return self.nameToTreeMarkerType[name]
end

function TreeMarkerSystem:getNumOfTreeMarkerTypes()
	return #self.treeMarkerTypes
end

function TreeMarkerSystem:addTreeMarkerCameraBased(shapeId, treeMarkerTypeIndex, r, g, b, a, camX, camY, camZ, hitX, hitY, hitZ, noEventSend)
	treeMarkerTypeIndex = treeMarkerTypeIndex or 0
	local treeMarkerType = self:getTreeMarkerTypeByIndex(treeMarkerTypeIndex)

	if treeMarkerType == nil then
		Logging.warning("No tree marker type found for tree marker type index '%d'", treeMarkerTypeIndex)

		return
	end

	local _, localHitY, _ = worldToLocal(shapeId, hitX, hitY, hitZ)
	local localCamX, _, localCamZ = worldToLocal(shapeId, camX, camY, camZ)
	local localDirX, localDirZ = MathUtil.vector2Normalize(localCamX, localCamZ)
	local angle = math.atan2(localDirX, localDirZ)
	local posX = 0
	local posY = localHitY
	local scale = treeMarkerType.scale or 0.4

	self:addTreeMarker(shapeId, treeMarkerTypeIndex, r, g, b, a, posX, posY, scale, angle, noEventSend)
end

function TreeMarkerSystem:addTreeMarkerByWorldDirection(shapeId, treeMarkerTypeIndex, r, g, b, a, dirX, dirZ, yOffset, scale, noEventSend)
	treeMarkerTypeIndex = treeMarkerTypeIndex or 0
	local treeMarkerType = self:getTreeMarkerTypeByIndex(treeMarkerTypeIndex)

	if treeMarkerType == nil then
		Logging.warning("No tree marker type found for tree marker type index '%d'", treeMarkerTypeIndex)

		return
	end

	local localDirX, _, localDirZ = worldDirectionToLocal(shapeId, dirX, 0, dirZ)
	local angle = math.atan2(localDirX, localDirZ)
	local posX = 0
	local posY = yOffset
	scale = scale or treeMarkerType.scale or 0.4

	self:addTreeMarker(shapeId, treeMarkerTypeIndex, r, g, b, a, posX, posY, scale, angle, noEventSend)
end

function TreeMarkerSystem:addTreeMarker(splitShapeId, treeMarkerTypeIndex, r, g, b, a, posX, posY, scale, rotY, noEventSend)
	if self.isServer and (noEventSend == nil or noEventSend == false) then
		local treeMarker = {
			splitShapeId = splitShapeId,
			treeMarkerTypeIndex = treeMarkerTypeIndex,
			r = r,
			g = g,
			b = b,
			a = a,
			posX = posX,
			posY = posY,
			scale = scale,
			rotY = rotY
		}

		g_server:broadcastEvent(TreeMarkerEvent.new({
			treeMarker
		}), false)
	end

	if splitShapeId ~= nil and entityExists(splitShapeId) then
		local treeMarkerType = self:getTreeMarkerTypeByIndex(treeMarkerTypeIndex)

		if treeMarkerType ~= nil and treeMarkerType.markerTexture ~= nil then
			local material = getMaterial(splitShapeId, 0)
			local newMaterialId = setMaterialCustomMap(material, self.shaderParameterMap, treeMarkerType.markerTexture, false)

			setMaterial(splitShapeId, newMaterialId, 0)
		end

		if getHasShaderParameter(splitShapeId, self.shaderParameter) then
			setShaderParameter(splitShapeId, self.shaderParameter, posX, posY, scale, rotY, false)
		end

		if getHasShaderParameter(splitShapeId, self.shaderParameterColor) then
			setShaderParameter(splitShapeId, self.shaderParameterColor, r, g, b, a, false)
		end

		self.treeMarkers[splitShapeId] = {
			splitShapeId = splitShapeId,
			treeMarkerTypeIndex = treeMarkerTypeIndex,
			r = r,
			g = g,
			b = b,
			a = a,
			posX = posX,
			posY = posY,
			scale = scale,
			rotY = rotY
		}
	end
end
