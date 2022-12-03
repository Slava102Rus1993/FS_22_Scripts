ScenariosScreen = {}
local ScenariosScreen_mt = Class(ScenariosScreen, ScreenElement)
ScenariosScreen.CONTROLS = {
	"list"
}

function ScenariosScreen.new(target, custom_mt, savegameController, startMissionInfo)
	local self = ScreenElement.new(target, custom_mt or ScenariosScreen_mt)

	self:registerControls(ScenariosScreen.CONTROLS)

	self.savegameController = savegameController
	self.startMissionInfo = startMissionInfo
	self.returnScreenName = "MainScreen"

	return self
end

function ScenariosScreen:onOpen()
	ScenariosScreen:superClass().onOpen(self)
	self.list:reloadData()
end

function ScenariosScreen:onStartAction(isMouseClick)
	local scenario = g_scenarioManager:getScenarioByIndex(self.list.selectedIndex)
	self.startMissionInfo.scenarioId = scenario.id
	self.startMissionInfo.difficulty = scenario.difficulty
	self.startMissionInfo.mapId = g_mapManager:getMapByConfigFilename(scenario.mapXMLFilename).id

	self:changeScreen(CareerScreen, ScenariosScreen)
end

function ScenariosScreen:getNumberOfItemsInSection(list, section)
	return g_scenarioManager:getNumScenarios()
end

function ScenariosScreen:populateCellForItemInSection(list, section, index, cell)
	local scenario = g_scenarioManager:getScenarioByIndex(index)

	cell:getAttribute("title"):setText(scenario.title)
	cell:getAttribute("gameIcon"):setImageFilename(scenario.iconFilename)
end

function ScenariosScreen:onListSelectionChanged(list, section, index)
end
