ScenarioManager = {}
local ScenarioManager_mt = Class(ScenarioManager, AbstractManager)

function ScenarioManager.new(customMt)
	return AbstractManager.new(customMt or ScenarioManager_mt)
end

function ScenarioManager:initDataStructures()
	self.scenarios = {}
	self.idToScenario = {}
end

function ScenarioManager:addScenarioItem(id, configXMLFilename, mapXMLFilename, vehiclesXMLFilename, placeablesXMLFilename, itemsXMLFilename, difficulty, title, description, iconFilename, isMod)
	if self.idToScenario[id] ~= nil then
		print("Warning: Duplicate scenario id (" .. id .. "). Ignoring this scenario definition.")

		return
	end

	local item = {
		id = tostring(id),
		configXMLFilename = configXMLFilename,
		mapXMLFilename = mapXMLFilename,
		vehiclesXMLFilename = vehiclesXMLFilename,
		placeablesXMLFilename = placeablesXMLFilename,
		itemsXMLFilename = itemsXMLFilename,
		title = title,
		description = description,
		iconFilename = iconFilename,
		isMod = isMod,
		difficulty = difficulty
	}

	table.insert(self.scenarios, item)

	self.idToScenario[id] = item
end

function ScenarioManager:loadScenarioFromXML(xmlFile, baseName, modDir, modName, isDLCFile)
	local scenarioId = xmlFile:getString(baseName .. "#id", "")
	local mapXMLFilename = xmlFile:getString(baseName .. "#mapXMLFilename", "")
	local vehiclesXMLFilename = xmlFile:getString(baseName .. "#vehiclesXMLFilename", "")
	local placeablesXMLFilename = xmlFile:getString(baseName .. "#placeablesXMLFilename", "")
	local itemsXMLFilename = xmlFile:getString(baseName .. "#itemsXMLFilename", "")
	local title = xmlFile:getI18NValue(baseName .. ".title", "", modName, true)
	local description = xmlFile:getI18NValue(baseName .. ".description", "", modName, true)
	local configXMLFilename = xmlFile:getString(baseName .. "#configXMLFilename", "")
	local iconFilename = xmlFile:getI18NValue(baseName .. ".iconFilename", "", modName, true)
	local difficulty = xmlFile:getInt(baseName .. "#difficulty", 1)

	if scenarioId == "" then
		print("Error: Failed to load mod scenario '" .. tostring(modName) .. "'. Missing attribute '" .. tostring(baseName) .. "#id'.")
	elseif title == "" then
		print("Error: Failed to load mod scenario '" .. tostring(modName) .. "'. Missing element: '" .. tostring(baseName) .. ".title'.")
	elseif description == "" then
		print("Error: Failed to load mod scenario '" .. tostring(modName) .. "'. Missing element: '" .. tostring(baseName) .. ".description'.")
	elseif mapXMLFilename == "" then
		print("Error: Failed to load mod scenario '" .. tostring(modName) .. "'. Missing attribute '" .. tostring(baseName) .. "#mapXMLFilename'.")
	elseif configXMLFilename == "" then
		print("Error: Failed to load mod scenario '" .. tostring(modName) .. "'. Missing attribute '" .. tostring(baseName) .. "#configXMLFilename'.")
	elseif vehiclesXMLFilename == "" then
		print("Error: Failed to load mod scenario '" .. tostring(modName) .. "'. Missing attribute '" .. tostring(baseName) .. "#vehiclesXMLFilename'.")
	elseif placeablesXMLFilename == "" then
		print("Error: Failed to load mod scenario '" .. tostring(modName) .. "'. Missing attribute '" .. tostring(baseName) .. "#placeablesXMLFilename'.")
	elseif itemsXMLFilename == "" then
		print("Error: Failed to load mod scenario '" .. tostring(modName) .. "'. Missing attribute '" .. tostring(baseName) .. "#itemsXMLFilename'.")
	elseif iconFilename == "" then
		print("Error: Failed to load mod scenario '" .. tostring(modName) .. "'. Missing element: '" .. tostring(baseName) .. ".iconFilename'.")
	else
		local baseDirectory = modDir
		local fullConfigFilename = Utils.getFilename(configXMLFilename, baseDirectory)
		scenarioId = modName .. "." .. scenarioId
		iconFilename = Utils.getFilename(iconFilename, baseDirectory)
		mapXMLFilename = Utils.getFilename(mapXMLFilename, baseDirectory)
		vehiclesXMLFilename = Utils.getFilename(vehiclesXMLFilename, baseDirectory)
		placeablesXMLFilename = Utils.getFilename(placeablesXMLFilename, baseDirectory)
		itemsXMLFilename = Utils.getFilename(itemsXMLFilename, baseDirectory)

		self:addScenarioItem(scenarioId, fullConfigFilename, mapXMLFilename, vehiclesXMLFilename, placeablesXMLFilename, itemsXMLFilename, difficulty, title, description, iconFilename, true)
	end
end

function ScenarioManager:getModNameFromScenarioId(scenarioId)
	local parts = string.split(scenarioId, ".")

	if #parts > 1 then
		return parts[1]
	end

	return nil
end

function ScenarioManager:getScenarioById(id)
	return self.idToScenario[id]
end

function ScenarioManager:removeScenarioItem(index)
	local item = self.scenarios[index]

	if item ~= nil then
		self.idToMap[item.id] = nil

		table.remove(self.scenarios, index)
	end
end

function ScenarioManager:getNumScenarios()
	return table.getn(self.scenarios)
end

function ScenarioManager:getScenarioByIndex(index)
	return self.scenarios[index]
end

g_scenarioManager = ScenarioManager.new()
