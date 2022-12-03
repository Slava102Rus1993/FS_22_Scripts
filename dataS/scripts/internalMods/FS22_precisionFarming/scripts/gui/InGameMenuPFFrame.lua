InGameMenuPFFrame = {}
local InGameMenuPFFrame_mt = Class(InGameMenuPFFrame, TabbedMenuFrameElement)
InGameMenuPFFrame.CONTROLS = {
	"mapOverviewSelector",
	"ingameMap",
	"mapCursor",
	"mapControls",
	"mapZoomGlyph",
	"mapMoveGlyph",
	"mapBox",
	"mapMoveGlyphText",
	"mapZoomGlyphText",
	"mapOverviewSoilBox",
	"valueMapFilterButton",
	"valueMapFilterColor",
	"valueMapFilterText",
	"laboratoryInfoText",
	"laboratoryWindow",
	"economicAnalysisWindow",
	"economicAnalysisHeaderField",
	"economicAnalysisHeaderValues",
	"buttonSwitchValues",
	"buttonResetStats",
	"statAmountText",
	"statCostText",
	"statPercentageText",
	"statTotalCostText",
	"statTotalCostPercentageText",
	"statTotalEarningsText",
	"statTotalEarningsPercentageText",
	"statTotalText",
	"statTotalPercentageText",
	"fieldBuyInfoWindow",
	"fieldBuyHeader",
	"soilNameText",
	"soilPercentageText",
	"soilPercentageBar",
	"yieldPercentageText",
	"yieldPercentageBarBase",
	"yieldPercentageBarPos",
	"yieldPercentageBarNeg",
	"resetYieldButtonBackground",
	"resetYieldButton",
	"helpButtonBackground",
	"helpButton",
	"envScoreWindow",
	"envScoreBarStatic",
	"envScoreBarDynamic",
	"envScoreBarIndicator",
	"envScoreBarNumber",
	"envScoreDistributionText",
	"envScoreDistributionBarBackground",
	"envScoreDistributionBar",
	"envScoreDistributionValue",
	"envScoreInfoText",
	"buttonAdditionalFunc",
	"buttonSelectIngame"
}
InGameMenuPFFrame.INPUT_CONTEXT_NAME = "MENU_PF"
InGameMenuPFFrame.MOD_NAME = g_currentModName
InGameMenuPFFrame.BUTTON_FRAME_SIDE = GuiElement.FRAME_RIGHT

local function NO_CALLBACK()
end

function InGameMenuPFFrame.new(subclass_mt, messageCenter, l10n, inputManager, inputDisplayManager, farmlandManager, farmManager)
	local self = TabbedMenuFrameElement.new(nil, subclass_mt or InGameMenuPFFrame_mt)

	self:registerControls(InGameMenuPFFrame.CONTROLS)

	self.inputManager = inputManager
	self.farmManager = farmManager
	self.farmlandManager = farmlandManager
	self.onClickBackCallback = NO_CALLBACK
	self.hasFullScreenMap = true
	self.hotspotFilterState = {}
	self.isColorBlindMode = g_gameSettings:getValue(GameSettings.SETTING.USE_COLORBLIND_MODE) or false
	self.isMapOverviewInitialized = false
	self.lastInputHelpMode = 0
	self.ingameMapBase = nil
	self.staticUIDeadzone = {
		0,
		0,
		0,
		0
	}
	self.needsSolidBackground = true
	self.precisionFarming = g_precisionFarming
	self.activeValueMapIndex = 1

	return self
end

function InGameMenuPFFrame:copyAttributes(src)
	InGameMenuPFFrame:superClass().copyAttributes(self, src)

	self.inputManager = src.inputManager
	self.farmlandManager = src.farmlandManager
	self.farmManager = src.farmManager
	self.onClickBackCallback = src.onClickBackCallback or NO_CALLBACK
end

function InGameMenuPFFrame:onGuiSetupFinished()
	InGameMenuPFFrame:superClass().onGuiSetupFinished(self)

	local _ = nil
	_, self.glyphTextSize = getNormalizedScreenValues(0, InGameMenuPFFrame.GLYPH_TEXT_SIZE)
	self.zoomText = g_i18n:getText(InGameMenuPFFrame.L10N_SYMBOL.INPUT_ZOOM_MAP)
	self.moveCursorText = g_i18n:getText(InGameMenuPFFrame.L10N_SYMBOL.INPUT_MOVE_CURSOR)
	self.panMapText = g_i18n:getText(InGameMenuPFFrame.L10N_SYMBOL.INPUT_PAN_MAP)
end

function InGameMenuPFFrame:delete()
	g_messageCenter:unsubscribeAll(self)
	self.farmlandManager:removeStateChangeListener(self)

	if self.soilStateOverlay ~= nil then
		delete(self.soilStateOverlay)
	end

	if self.farmlandSelectionOverlay ~= nil then
		delete(self.farmlandSelectionOverlay)
	end

	if self.coverStateOverlays ~= nil then
		for i = 1, #self.coverStateOverlays do
			delete(self.coverStateOverlays[i].overlay)
		end
	end

	InGameMenuPFFrame:superClass().delete(self)
end

function InGameMenuPFFrame:initialize(onClickBackCallback)
	if not GS_IS_MOBILE_VERSION then
		self:updateInputGlyphs()
	end

	self.deadzoneElements = {
		self.economicAnalysisWindow,
		self.laboratoryWindow,
		self.mapOverviewSelector
	}
	self.onClickBackCallback = onClickBackCallback or NO_CALLBACK
end

function InGameMenuPFFrame:onFrameOpen()
	InGameMenuPFFrame:superClass().onFrameOpen(self)

	self.isOpen = true

	self:toggleCustomInputContext(true, InGameMenuPFFrame.INPUT_CONTEXT_NAME)
	self.inputManager:removeActionEventsByActionName(InputAction.MENU_EXTRA_2)
	self.ingameMap:onOpen()
	self.ingameMap:registerActionEvents()

	for k, v in pairs(self.ingameMapBase.filter) do
		self.hotspotFilterState[k] = v

		self.ingameMapBase:setHotspotFilter(k, false)
	end

	self.ingameMapBase:setHotspotFilter(MapHotspot.CATEGORY_FIELD, true)
	self.ingameMapBase:setHotspotFilter(MapHotspot.CATEGORY_COMBINE, true)
	self.ingameMapBase:setHotspotFilter(MapHotspot.CATEGORY_STEERABLE, true)
	self.ingameMapBase:setHotspotFilter(MapHotspot.CATEGORY_PLAYER, true)

	self.mapOverviewZoom = 1
	self.mapOverviewCenterX = 0.5
	self.mapOverviewCenterY = 0.5

	if self.visible and not self.isMapOverviewInitialized then
		self:setupMapOverview()
	end

	local precisionFarming = self.precisionFarming

	if precisionFarming.environmentalScore ~= nil then
		precisionFarming.environmentalScore:onMapFrameOpen(self)
	end

	local isColorBlindMode = g_gameSettings:getValue(GameSettings.SETTING.USE_COLORBLIND_MODE)

	if self.isColorBlindMode ~= isColorBlindMode then
		self.isColorBlindMode = isColorBlindMode

		if self.visible and self.isMapOverviewInitialized then
			self:setActiveValueMap()
		end
	elseif self.visible and self.isMapOverviewInitialized then
		self:updateSoilStateMapOverlay()
	end

	FocusManager:setFocus(self.mapOverviewSelector)
	self:updateInputGlyphs()
	self:updateAdditionalFunctionButton()
end

function InGameMenuPFFrame:onFrameClose()
	self.ingameMap:onClose()
	self:toggleCustomInputContext(false, InGameMenuPFFrame.INPUT_CONTEXT_NAME)

	for k, v in pairs(self.ingameMapBase.filter) do
		self.ingameMapBase:setHotspotFilter(k, self.hotspotFilterState[k])
	end

	self.isOpen = false

	InGameMenuPFFrame:superClass().onFrameClose(self)
end

function InGameMenuPFFrame:onLoadMapFinished()
	self.soilStateOverlay = createDensityMapVisualizationOverlay("soilState", 1024, 1024)

	setDensityMapVisualizationOverlayUpdateTimeLimit(self.soilStateOverlay, 20)

	self.soilStateOverlayReady = false
	self.farmlandSelectionOverlay = createDensityMapVisualizationOverlay("farmlandSelection", 512, 512)

	setDensityMapVisualizationOverlayUpdateTimeLimit(self.farmlandSelectionOverlay, 20)

	self.farmlandSelectionOverlayReady = false
	local coverMap = self.precisionFarming.coverMap

	if coverMap ~= nil then
		self.coverStateOverlays = {}

		for i = 1, coverMap:getNumCoverOverlays() do
			local coverStateOverlay = {
				overlay = createDensityMapVisualizationOverlay("coverState" .. i, 1024, 1024)
			}

			setDensityMapVisualizationOverlayUpdateTimeLimit(coverStateOverlay.overlay, 20)

			coverStateOverlay.overlayReady = false

			table.insert(self.coverStateOverlays, coverStateOverlay)
		end
	end

	self.precisionFarming:registerVisualizationOverlay(self.soilStateOverlay)
	self.precisionFarming:registerVisualizationOverlay(self.farmlandSelectionOverlay)

	for i = 1, #self.coverStateOverlays do
		self.precisionFarming:registerVisualizationOverlay(self.coverStateOverlays[i].overlay)
	end
end

function InGameMenuPFFrame:reset()
	InGameMenuPFFrame:superClass().reset(self)

	self.isMapOverviewInitialized = false

	InGameMenuMapUtil.hideContextBox(self.contextBox)
end

function InGameMenuPFFrame:mouseEvent(posX, posY, isDown, isUp, button, eventUsed)
	return InGameMenuPFFrame:superClass().mouseEvent(self, posX, posY, isDown, isUp, button, eventUsed)
end

function InGameMenuPFFrame:update(dt)
	InGameMenuPFFrame:superClass().update(self, dt)

	local currentInputHelpMode = self.inputManager:getInputHelpMode()

	if currentInputHelpMode ~= self.lastInputHelpMode then
		self.lastInputHelpMode = currentInputHelpMode

		PrecisionFarmingGUI.updateButtonOnInputHelpChange(self.helpButton, "ingameMenuPrecisionFarmingHelpButtonConsole", "ingameMenuPrecisionFarmingHelpButton")
		self.buttonSelectIngame:setVisible(currentInputHelpMode == GS_INPUT_HELP_MODE_GAMEPAD)

		if self.precisionFarming.environmentalScore ~= nil then
			self.precisionFarming.environmentalScore:setInputHelpMode(currentInputHelpMode)
		end

		if not GS_IS_MOBILE_VERSION then
			self:updateInputGlyphs()
			self:updateAdditionalFunctionButton()
		end
	end
end

function InGameMenuPFFrame:setTargetPointHotspotPosition(localX, localY)
end

function InGameMenuPFFrame:setInGameMap(ingameMap)
	self.ingameMapBase = ingameMap

	self.ingameMap:setIngameMap(ingameMap)
end

function InGameMenuPFFrame:setTerrainSize(terrainSize)
	self.ingameMap:setTerrainSize(terrainSize)
end

function InGameMenuPFFrame:setMissionFruitTypes(missionFruitTypes)
	self.missionFruitTypes = missionFruitTypes
end

function InGameMenuPFFrame:setClient(client)
	self.client = client
end

function InGameMenuPFFrame:resetUIDeadzones()
	self.ingameMap:clearCursorDeadzones()

	for i = 1, #self.deadzoneElements do
		local element = self.deadzoneElements[i]

		if element:getIsVisible() then
			self.ingameMap:addCursorDeadzone(element.absPosition[1], element.absPosition[2], element.size[1], element.size[2])
		end
	end
end

function InGameMenuPFFrame:setStaticUIDeadzone(screenX, screenY, width, height)
	self.staticUIDeadzone = {
		screenX,
		screenY,
		width,
		height
	}
end

function InGameMenuPFFrame:setupMapOverview()
	self.isMapOverviewInitialized = true
	local precisionFarming = self.precisionFarming

	if precisionFarming.soilMap ~= nil then
		precisionFarming.soilMap:setMapFrame(self)
	end

	if precisionFarming.farmlandStatistics ~= nil then
		precisionFarming.farmlandStatistics:setMapFrame(self)
	end

	if precisionFarming.yieldMap ~= nil then
		precisionFarming.yieldMap:setMapFrame(self)
	end

	if precisionFarming.environmentalScore ~= nil then
		precisionFarming.environmentalScore:setMapFrame(self)
	end

	self.mapSelectorTexts = {}
	local valueMaps = self.precisionFarming:getValueMaps()

	for i = 1, #valueMaps do
		local valueMap = valueMaps[i]

		if valueMap:getShowInMenu() then
			table.insert(self.mapSelectorTexts, valueMap:getOverviewLabel())
		end
	end

	self.mapOverviewSelector:setTexts(self.mapSelectorTexts)
	self:setActiveValueMap()
	self:updateFarmlandSelection()
end

function InGameMenuPFFrame:updateFarmlandSelection()
	if self.precisionFarming.farmlandStatistics ~= nil then
		self.precisionFarming.farmlandStatistics:buildOverlay(self.farmlandSelectionOverlay)
		generateDensityMapVisualizationOverlay(self.farmlandSelectionOverlay)

		self.farmlandSelectionOverlayReady = false
	end
end

function InGameMenuPFFrame:setActiveValueMap(valueMapindex)
	valueMapindex = valueMapindex or self.activeValueMapIndex

	if valueMapindex ~= nil then
		local valueMaps = self.precisionFarming:getValueMaps()
		local valueMap = valueMaps[valueMapindex]
		local displayValues = valueMap:getDisplayValues()
		local valueFilter, valueFilterEnabled = valueMap:getValueFilter()

		for i = 1, #self.valueMapFilterButton do
			if i <= #valueFilter then
				local filterButton = self.valueMapFilterButton[i]

				filterButton:setVisible(true)
				filterButton:toggleFrameSide(InGameMenuMapFrame.BUTTON_FRAME_SIDE, false)

				filterButton.onHighlightCallback = self.onFilterButtonSelect
				filterButton.onHighlightRemoveCallback = self.onFilterButtonUnselect
				filterButton.onFocusCallback = self.onFilterButtonSelect
				filterButton.onLeaveCallback = self.onFilterButtonUnselect
				local state = displayValues[i]
				local colors = state.colors[self.isColorBlindMode]

				self.valueMapFilterColor[i]:setImageColor(GuiOverlay.STATE_NORMAL, unpack(colors[1]))
				self.valueMapFilterText[i]:setText(state.description)

				if valueFilterEnabled == nil or valueFilterEnabled[i] then
					function filterButton.onClickCallback()
						self:onClickValueFilter(filterButton, i)
					end
				else
					filterButton.onClickCallback = nil
				end

				for _, child in pairs(filterButton.elements) do
					child:setDisabled(not valueFilter[i])
				end
			else
				self.valueMapFilterButton[i]:setVisible(false)
			end
		end

		self.activeValueMapIndex = valueMapindex

		for i = 1, #valueMaps do
			if valueMaps[i].onValueMapSelectionChanged ~= nil then
				valueMaps[i]:onValueMapSelectionChanged(valueMap)
			end
		end

		self:updateSoilStateMapOverlay()
		self:updateAdditionalFunctionButton()
	end
end

function InGameMenuPFFrame:updateSoilStateMapOverlay()
	local valueMaps = self.precisionFarming:getValueMaps()
	local valueMap = valueMaps[self.activeValueMapIndex]

	if valueMap ~= nil then
		local valueFilter, _ = valueMap:getValueFilter()

		valueMap:buildOverlay(self.soilStateOverlay, valueFilter, self.isColorBlindMode)
		generateDensityMapVisualizationOverlay(self.soilStateOverlay)

		self.soilStateOverlayReady = false
	end

	local coverMap = self.precisionFarming.coverMap

	if coverMap ~= nil then
		for i = 1, #self.coverStateOverlays do
			local coverStateOverlay = self.coverStateOverlays[i]

			coverMap:buildCoverStateOverlay(coverStateOverlay.overlay, i)
			generateDensityMapVisualizationOverlay(coverStateOverlay.overlay)

			coverStateOverlay.overlayReady = false
		end
	end
end

function InGameMenuPFFrame:updateAdditionalFunctionButton()
	local isActive = false
	local valueMaps = self.precisionFarming:getValueMaps()
	local valueMap = valueMaps[self.activeValueMapIndex]

	if valueMap ~= nil then
		local farmlandId = nil

		if self.precisionFarming.farmlandStatistics ~= nil then
			farmlandId = self.precisionFarming.farmlandStatistics:getSelectedFarmland()
		end

		isActive = valueMap:getRequiresAdditionalActionButton(farmlandId)

		if isActive then
			local text = valueMap:getAdditionalActionButtonText()

			self.buttonAdditionalFunc:setText(text)
		end
	end

	if not isActive then
		if self.lastInputHelpMode == GS_INPUT_HELP_MODE_GAMEPAD then
			isActive = true

			self.buttonAdditionalFunc:setText(g_i18n:getText("ui_environmentalScoreShowDetails"))
		else
			self:setEnvironmentalScoreWindowState(false)
		end
	else
		self:setEnvironmentalScoreWindowState(false)
	end

	self.buttonAdditionalFunc:setVisible(isActive)
	self.buttonAdditionalFunc.parent:invalidateLayout()
end

function InGameMenuPFFrame:setMapSelectionItem(hotspot)
end

function InGameMenuPFFrame:setMapSelectionPosition(worldX, worldZ)
end

function InGameMenuPFFrame:setEnvironmentalScoreWindowState(state)
	if self.precisionFarming.environmentalScore ~= nil then
		self.precisionFarming.environmentalScore:toggleWindowSize(state)
	end
end

function InGameMenuPFFrame:onClickMapOverviewSelector(state)
	self:setActiveValueMap(state)
end

function InGameMenuPFFrame:onClickValueFilter(button, index)
	local valueMaps = self.precisionFarming:getValueMaps()
	local valueMap = valueMaps[self.activeValueMapIndex]
	local valueFilter, _ = valueMap:getValueFilter()

	if valueFilter ~= nil then
		valueFilter[index] = not valueFilter[index]

		for i = 1, #self.valueMapFilterButton do
			for _, child in pairs(self.valueMapFilterButton[i].elements) do
				child:setDisabled(not valueFilter[i])
			end
		end

		button:toggleFrameSide(InGameMenuMapFrame.BUTTON_FRAME_SIDE, false)
		self:updateSoilStateMapOverlay()
	end
end

function InGameMenuPFFrame.onFilterButtonSelect(_, button)
	button:toggleFrameSide(InGameMenuMapFrame.BUTTON_FRAME_SIDE, true)
end

function InGameMenuPFFrame.onFilterButtonUnselect(_, button)
	button:toggleFrameSide(InGameMenuMapFrame.BUTTON_FRAME_SIDE, false)

	for _, child in pairs(button.elements) do
		child:setDisabled(child:getIsDisabled())
	end
end

function InGameMenuPFFrame:onClickButtonHelp()
	local valueMaps = self.precisionFarming:getValueMaps()
	local valueMap = valueMaps[self.activeValueMapIndex]

	if valueMap ~= nil then
		self.precisionFarming.helplineExtension:openHelpMenu(valueMap:getHelpLinePage())
	else
		self.precisionFarming.helplineExtension:openHelpMenu(0)
	end
end

function InGameMenuPFFrame:onClickButtonResetStats()
	if self.precisionFarming.farmlandStatistics ~= nil then
		self.precisionFarming.farmlandStatistics:onClickButtonResetStats()
	end
end

function InGameMenuPFFrame:onClickButtonSwitchValues()
	if self.precisionFarming.farmlandStatistics ~= nil then
		self.precisionFarming.farmlandStatistics:onClickButtonSwitchValues()
	end
end

function InGameMenuPFFrame:onDrawPostIngameMap(element, ingameMap)
	local width, height = self.ingameMapBase.fullScreenLayout:getMapSize()
	local x, y = self.ingameMapBase.fullScreenLayout:getMapPosition()

	if not self.farmlandSelectionOverlayReady and getIsDensityMapVisualizationOverlayReady(self.farmlandSelectionOverlay) then
		self.farmlandSelectionOverlayReady = true
	end

	if self.farmlandSelectionOverlayReady and self.farmlandSelectionOverlay ~= 0 then
		setOverlayUVs(self.farmlandSelectionOverlay, 0, 0, 0, 1, 1, 0, 1, 1)
		renderOverlay(self.farmlandSelectionOverlay, x + width * 0.25, y + height * 0.25, width * 0.5, height * 0.5)
	end

	if not self.soilStateOverlayReady and getIsDensityMapVisualizationOverlayReady(self.soilStateOverlay) then
		self.soilStateOverlayReady = true
	end

	if self.soilStateOverlayReady and self.soilStateOverlay ~= 0 then
		setOverlayUVs(self.soilStateOverlay, 0, 0, 0, 1, 1, 0, 1, 1)
		renderOverlay(self.soilStateOverlay, x + width * 0.25, y + height * 0.25, width * 0.5, height * 0.5)
	end

	local allowCoverage = false
	local valueMaps = self.precisionFarming:getValueMaps()
	local valueMap = valueMaps[self.activeValueMapIndex]

	if valueMap ~= nil then
		allowCoverage = valueMap:getAllowCoverage()
	end

	if allowCoverage then
		local coverMap = self.precisionFarming.coverMap

		if coverMap ~= nil then
			for i = 1, #self.coverStateOverlays do
				local coverStateOverlay = self.coverStateOverlays[i]

				if not coverStateOverlay.overlayReady and getIsDensityMapVisualizationOverlayReady(coverStateOverlay.overlay) then
					coverStateOverlay.overlayReady = true
				end

				if coverStateOverlay.overlayReady and coverStateOverlay.overlay ~= 0 then
					setOverlayUVs(coverStateOverlay.overlay, 0, 0, 0, 1, 1, 0, 1, 1)
					renderOverlay(coverStateOverlay.overlay, x + width * 0.25, y + height * 0.25, width * 0.5, height * 0.5)
				end
			end
		end
	end
end

function InGameMenuPFFrame:onDrawPostIngameMapHotspots(element, ingameMap)
	if self.activeValueMapIndex == 1 and self.precisionFarming.environmentalScore ~= nil then
		self.precisionFarming.environmentalScore:onDraw(element, ingameMap)
	end
end

function InGameMenuPFFrame:onClickMap(element, worldX, worldZ)
	local farmlandId = self.farmlandManager:getFarmlandIdAtWorldPosition(worldX, worldZ)

	if farmlandId ~= nil and self.precisionFarming.farmlandStatistics ~= nil then
		self.precisionFarming.farmlandStatistics:onClickMapFarmland(farmlandId)
		self:updateFarmlandSelection()
	end
end

function InGameMenuPFFrame:updateInputGlyphs()
	local moveActions, moveText = nil

	if self.lastInputHelpMode == GS_INPUT_HELP_MODE_GAMEPAD then
		moveText = self.moveCursorText
		moveActions = {
			InputAction.AXIS_MAP_SCROLL_LEFT_RIGHT,
			InputAction.AXIS_MAP_SCROLL_UP_DOWN
		}
	else
		moveText = self.panMapText
		moveActions = {
			InputAction.AXIS_LOOK_LEFTRIGHT_DRAG,
			InputAction.AXIS_LOOK_UPDOWN_DRAG
		}
	end

	self.mapMoveGlyph:setActions(moveActions, nil, , true, true)
	self.mapZoomGlyph:setActions({
		InputAction.AXIS_MAP_ZOOM_IN,
		InputAction.AXIS_MAP_ZOOM_OUT
	}, nil, , false, true)
	self.mapMoveGlyphText:setText(moveText)
	self.mapZoomGlyphText:setText(self.zoomText)
end

function InGameMenuPFFrame:hasMouseOverlapInFrame()
	return GuiUtils.checkOverlayOverlap(g_lastMousePosX, g_lastMousePosY, self.absPosition[1], self.absPosition[2], self.absSize[1], self.absSize[2])
end

function InGameMenuPFFrame:onZoomIn()
	if self:hasMouseOverlapInFrame() then
		self.ingameMap:zoom(1)
	end
end

function InGameMenuPFFrame:onZoomOut()
	if self:hasMouseOverlapInFrame() then
		self.ingameMap:zoom(-1)
	end
end

function InGameMenuPFFrame:onClickBack()
	self:onClickBackCallback()
end

function InGameMenuPFFrame:onClickAdditionalFuncButton()
	local usedEvent = false
	local valueMaps = self.precisionFarming:getValueMaps()
	local valueMap = valueMaps[self.activeValueMapIndex]

	if valueMap ~= nil then
		local farmlandId = nil

		if self.precisionFarming.farmlandStatistics ~= nil then
			farmlandId = self.precisionFarming.farmlandStatistics:getSelectedFarmland()
		end

		if valueMap:getRequiresAdditionalActionButton(farmlandId) then
			valueMap:onAdditionalActionButtonPressed(farmlandId)

			usedEvent = true
		end
	end

	if not usedEvent and self.lastInputHelpMode == GS_INPUT_HELP_MODE_GAMEPAD then
		self:setEnvironmentalScoreWindowState()
	end
end

InGameMenuPFFrame.GLYPH_TEXT_SIZE = 20
InGameMenuPFFrame.L10N_SYMBOL = {
	INPUT_PAN_MAP = "ui_ingameMenuMapPan",
	INPUT_ZOOM_MAP = "ui_ingameMenuMapZoom",
	INPUT_MOVE_CURSOR = "ui_ingameMenuMapMoveCursor"
}
