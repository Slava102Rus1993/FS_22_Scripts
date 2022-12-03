InGameMenuExtension = {
	MOD_NAME = g_currentModName,
	MOD_DIR = g_currentModDirectory,
	GUI_ELEMENTS = g_currentModDirectory .. "gui/ui_elements.png",
	GUI_ELEMENTS_SIZE = {
		1024,
		1024
	},
	GUI_FRAME_REF_XML = g_currentModDirectory .. "gui/IngameMenuPFFrameReference.xml"
}
local InGameMenuExtension_mt = Class(InGameMenuExtension)

function InGameMenuExtension.new(customMt)
	local self = setmetatable({}, customMt or InGameMenuExtension_mt)

	return self
end

function InGameMenuExtension:unloadMapData()
end

function InGameMenuExtension:delete()
end

function InGameMenuExtension:update(dt)
end

function InGameMenuExtension:updatePrecisionFarmingOverlays()
	if self.inGameMenuPFFrame ~= nil then
		self.inGameMenuPFFrame:updateSoilStateMapOverlay()
	end
end

function InGameMenuExtension.sortPrecisionFarmingPage()
	local inGameMenu = g_gui.screenControllers[InGameMenu]
	local orderId = inGameMenu.pageTour ~= nil and 3 or 2

	for i = 1, #inGameMenu.pagingElement.elements do
		local child = inGameMenu.pagingElement.elements[i]

		if child == inGameMenu.pagePF then
			table.remove(inGameMenu.pagingElement.elements, i)
			table.insert(inGameMenu.pagingElement.elements, orderId, child)

			break
		end
	end

	for i = 1, #inGameMenu.pagingElement.pages do
		local child = inGameMenu.pagingElement.pages[i]

		if child.element == inGameMenu.pagePF then
			table.remove(inGameMenu.pagingElement.pages, i)
			table.insert(inGameMenu.pagingElement.pages, orderId, child)

			break
		end
	end
end

function InGameMenuExtension.sortPrecisionFarmingPageFrame()
	local inGameMenu = g_gui.screenControllers[InGameMenu]
	local orderId = inGameMenu.pageTour ~= nil and 3 or 2

	for i = 1, #inGameMenu.pageFrames do
		local child = inGameMenu.pageFrames[i]

		if child == inGameMenu.pagePF then
			table.remove(inGameMenu.pageFrames, i)
			table.insert(inGameMenu.pageFrames, orderId, child)

			break
		end
	end

	inGameMenu:rebuildTabList()
end

function InGameMenuExtension:overwriteGameFunctions(pfModule)
	local inGameMenu = g_gui.screenControllers[InGameMenu]
	local xmlFile = loadXMLFile("Temp", InGameMenuExtension.GUI_FRAME_REF_XML)

	if xmlFile ~= nil and xmlFile ~= 0 then
		for k, v in pairs({
			"pagePF"
		}) do
			inGameMenu.controlIDs[v] = nil
		end

		inGameMenu:registerControls({
			"pagePF"
		})
		g_gui:loadGuiRec(xmlFile, "inGameMenuPFFrameReference", inGameMenu.pagingElement, self)
		inGameMenu:exposeControlsAsFields("pagePF")
		InGameMenuExtension.sortPrecisionFarmingPage()
		inGameMenu.pagingElement:updateAbsolutePosition()
		inGameMenu.pagingElement:updatePageMapping()
		delete(xmlFile)
	end

	self.inGameMenuPFFrame = g_gui:resolveFrameReference(inGameMenu.pagePF)
	local inGameMenuPFFrame = self.inGameMenuPFFrame

	pfModule:overwriteGameFunction(InGameMenu, "setInGameMap", function (superFunc, self, inGameMap)
		inGameMenuPFFrame:setInGameMap(inGameMap)
		superFunc(self, inGameMap)
	end)
	pfModule:overwriteGameFunction(InGameMenu, "setTerrainSize", function (superFunc, self, terrainSize)
		inGameMenuPFFrame:setTerrainSize(terrainSize)
		superFunc(self, terrainSize)
	end)
	pfModule:overwriteGameFunction(InGameMenu, "onLoadMapFinished", function (superFunc, self)
		inGameMenuPFFrame:onLoadMapFinished()
		InGameMenuExtension.sortPrecisionFarmingPage()
		InGameMenuExtension.sortPrecisionFarmingPageFrame()
		superFunc(self)
	end)
	pfModule:overwriteGameFunction(TabbedMenu, "onPageChange", function (superFunc, self, pageIndex, pageMappingIndex, element, skipTabVisualUpdate)
		if self.pageMapOverview ~= nil and self.pageAI ~= nil and self.pagePF ~= nil then
			local prevPage = self.pagingElement:getPageElementByIndex(self.currentPageId)

			if prevPage == self.pageMapOverview then
				self.pageAI.ingameMap:copySettingsFromElement(self.pageMapOverview.ingameMap)
				self.pagePF.ingameMap:copySettingsFromElement(self.pageMapOverview.ingameMap)
			elseif prevPage == self.pageAI then
				self.pageMapOverview.ingameMap:copySettingsFromElement(self.pageAI.ingameMap)
				self.pagePF.ingameMap:copySettingsFromElement(self.pageAI.ingameMap)
			elseif prevPage == self.pagePF then
				self.pageAI.ingameMap:copySettingsFromElement(self.pagePF.ingameMap)
				self.pageMapOverview.ingameMap:copySettingsFromElement(self.pagePF.ingameMap)
			end
		end

		superFunc(self, pageIndex, pageMappingIndex, element, skipTabVisualUpdate)
	end)
	inGameMenu:registerPage(inGameMenu.pagePF, 19, function ()
		return true
	end)
	inGameMenu:addPageTab(inGameMenu.pagePF, InGameMenuExtension.GUI_ELEMENTS, GuiUtils.getUVs({
		129,
		1,
		62,
		62
	}))
	inGameMenu.pagePF:applyScreenAlignment()
	inGameMenu.pagePF:updateAbsolutePosition()
	inGameMenu.pagePF:onGuiSetupFinished()
	InGameMenuExtension.sortPrecisionFarmingPageFrame()
	self.inGameMenuPFFrame:initialize(inGameMenu.clickBackCallback)
end

if g_gui ~= nil then
	local frameController = InGameMenuPFFrame.new(nil, g_messageCenter, g_i18n, g_inputBinding, g_inputDisplayManager, g_farmlandManager, g_farmManager)

	g_gui:loadGui(InGameMenuExtension.MOD_DIR .. "gui/InGameMenuPFFrame.xml", "PFFrame", frameController, true)
end
