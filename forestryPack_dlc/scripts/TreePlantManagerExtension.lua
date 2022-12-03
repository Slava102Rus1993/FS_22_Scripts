local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

local modDirectory = g_currentModDirectory

function TreePlantManager:canPlantTree()
	local totalNumSplit, numSplit = getNumOfSplitShapes()
	local numUnsplit = totalNumSplit - numSplit
	local maxNumSplitShapes = TreePlantManager.MAX_NUM_OF_SPLITSHAPES

	if g_currentMission.missionInfo.mapId == "pdlc_forestryPack.MapForest" then
		maxNumSplitShapes = 21200
	end

	return maxNumSplitShapes > numUnsplit + self.numTreesWithoutSplits
end

local function loadCustomTreeTypes()
	local filename = modDirectory .. "modDesc.xml"

	if isDlc then
		filename = modDirectory .. "dlcDesc.xml"
	end

	local xmlFile = loadXMLFile("ModFile", filename)
	local i = 0

	while true do
		local key = string.format("modDesc.treeTypes.treeType(%d)", i)

		if not hasXMLProperty(xmlFile, key) then
			break
		end

		local typeName = getXMLString(xmlFile, key .. "#name")
		local baseTypeName = getXMLString(xmlFile, key .. "#baseTypeName")

		if typeName ~= nil and baseTypeName ~= nil then
			local baseTreeType = g_treePlantManager:getTreeTypeDescFromName(baseTypeName)

			if baseTreeType ~= nil and g_treePlantManager:getTreeTypeDescFromName(typeName) == nil then
				local filenames = {}

				for j = 1, #baseTreeType.treeFilenames do
					table.insert(filenames, baseTreeType.treeFilenames[j])
				end

				local j = 0

				while true do
					local stageKey = string.format("%s.stage(%d)", key, j)

					if not hasXMLProperty(xmlFile, stageKey) then
						break
					end

					local stageIndex = getXMLInt(xmlFile, stageKey .. "#index")
					local stageFilename = getXMLString(xmlFile, stageKey .. "#filename")

					if stageIndex ~= nil and stageFilename ~= nil then
						stageFilename = Utils.getFilename(stageFilename, modDirectory)

						if fileExists(stageFilename) then
							filenames[stageIndex] = stageFilename
						else
							Logging.warning("Could not find tree stage i3d file '%s'", stageFilename)
						end
					end

					j = j + 1
				end

				g_treePlantManager:registerTreeType(typeName, baseTreeType.nameI18N, filenames, baseTreeType.growthTimeHours, false)
			end
		end

		i = i + 1
	end

	delete(xmlFile)
end

TreePlantManager.loadMapData = Utils.overwrittenFunction(TreePlantManager.loadMapData, function (self, superFunc, xmlFile, missionInfo, baseDirectory)
	local success = superFunc(self, xmlFile, missionInfo, baseDirectory)

	loadCustomTreeTypes()

	local storeItems = g_storeManager:getItems()

	for i = 1, #storeItems do
		local storeItem = storeItems[i]

		if storeItem.configurations ~= nil then
			local configItems = storeItem.configurations.treeSaplingType

			if configItems ~= nil then
				local vehicleXMLFile = XMLFile.load("vehicleXMLFileTemp", storeItem.xmlFilename, Vehicle.xmlSchema)

				for j = #configItems, 1, -1 do
					local key = string.format("vehicle.treeSaplingPallet.treeSaplingTypeConfigurations.treeSaplingTypeConfiguration(%d)", j - 1)

					if vehicleXMLFile:hasProperty(key) then
						local treeTypeName = vehicleXMLFile:getValue(key .. "#treeType", "spruce1")

						if g_treePlantManager:getTreeTypeDescFromName(treeTypeName) == nil then
							table.remove(configItems, j)
						end
					end
				end

				for j = 1, #configItems do
					configItems[j].index = j
				end

				vehicleXMLFile:delete()
			end
		end
	end

	return success
end)
