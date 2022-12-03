HelplineExtension = {
	MOD_NAME = g_currentModName,
	MOD_DIR = g_currentModDirectory,
	GUI_EXT_XML = g_currentModDirectory .. "gui/HelpFrameSeedRateExtension.xml"
}
local HelplineExtension_mt = Class(HelplineExtension)

function HelplineExtension.new(pfModule, customMt)
	local self = setmetatable({}, customMt or HelplineExtension_mt)
	self.pfModule = pfModule

	return self
end

function HelplineExtension:loadFromXML(xmlFile, key, baseDirectory, configFileName, mapFilename)
	self.additionalFilename = Utils.getFilename(getXMLString(xmlFile, key .. "#filename"), HelplineExtension.MOD_DIR)

	return true
end

function HelplineExtension:delete()
	if self.precisionFarmingSeedRateContainer ~= nil then
		self.precisionFarmingSeedRateContainer:delete()

		self.precisionFarmingSeedRateContainer = nil
	end
end

function HelplineExtension:getAllowFirstTimeEvent()
	return not g_currentMission.hud:isInGameMessageVisible() and not g_gui:getIsGuiVisible()
end

function HelplineExtension:onFirstTimeRun()
	g_gui:showYesNoDialog({
		text = g_i18n:getText("precisionFarming_firstStart", HelplineExtension.MOD_NAME),
		callback = self.onFirstTimeRunDialog,
		target = self
	})
end

function HelplineExtension:onFirstTimeRunDialog(yes)
	if yes then
		self:openHelpMenu(1)
	end
end

function HelplineExtension:openHelpMenu(offsetIndex)
	if g_gui.currentGuiName ~= "InGameMenu" then
		g_gui:showGui("InGameMenu")
	end

	if g_currentMission ~= nil then
		local inGameMenu = g_currentMission.inGameMenu
		local helpLinePage = inGameMenu.pageHelpLine

		inGameMenu:goToPage(helpLinePage)
		helpLinePage:openPage(helpLinePage:getNumberOfSections(), offsetIndex)
		helpLinePage.helpLineList:smoothScrollTo(math.huge)
	end
end

function HelplineExtension:fillSeedRateRows(contentBox, template)
	if self.pfModule.seedRateMap ~= nil then
		self.pfModule.seedRateMap:createHelpMenuSeedRateTable(contentBox, template)
	end
end

function HelplineExtension:overwriteGameFunctions(pfModule)
	local helplineExtension = self

	pfModule:overwriteGameFunction(HelpLineManager, "loadMapData", function (superFunc, self, xmlFile, missionInfo)
		if not superFunc(self, xmlFile, missionInfo) then
			return false
		end

		local filename = pfModule.helplineExtension.additionalFilename

		if filename ~= nil and filename ~= "" then
			self:loadFromXML(filename)
		end
	end)
	pfModule:overwriteGameFunction(InGameMenuHelpFrame, "updateContents", function (superFunc, self, page)
		superFunc(self, page)

		if #page.paragraphs > 0 then
			local lastParagraph = page.paragraphs[#page.paragraphs]

			if lastParagraph.text == "$l10n_helpText_07_part03" and lastParagraph.customEnvironment == HelplineExtension.MOD_NAME then
				helplineExtension:fillSeedRateRows(self.helpLineContentBox, self.precisionFarmingSeedRateRowTemplate)
			end
		end
	end)
	pfModule:overwriteGameFunction(InGameMenuHelpFrame, "onFrameOpen", function (superFunc, self)
		if helplineExtension.precisionFarmingSeedRateContainer == nil then
			local xmlFile = loadXMLFile("Temp", HelplineExtension.GUI_EXT_XML)

			if xmlFile ~= nil and xmlFile ~= 0 then
				if #self.elements > 0 then
					local rootElement = self.elements[1]

					g_gui:loadGuiRec(xmlFile, "helpFrameSeedRateExtension", rootElement, self)
					self:exposeControlsAsFields("MapFrame")
					self:onGuiSetupFinished()

					self.precisionFarmingSeedRateContainer = rootElement.elements[#rootElement.elements]

					self.precisionFarmingSeedRateContainer:applyScreenAlignment()
					self.precisionFarmingSeedRateContainer:updateAbsolutePosition()
					self.precisionFarmingSeedRateContainer:unlinkElement()
					self.precisionFarmingSeedRateContainer:setVisible(false)

					helplineExtension.precisionFarmingSeedRateContainer = self.precisionFarmingSeedRateContainer
					self.precisionFarmingSeedRateRowTemplate = self.precisionFarmingSeedRateContainer.elements[1]
				end

				delete(xmlFile)
			end
		end

		superFunc(self)
	end)
end
