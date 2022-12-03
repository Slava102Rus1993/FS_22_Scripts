InGameMapExtension = {
	MOD_NAME = g_currentModName,
	MOD_DIR = g_currentModDirectory,
	GUI_ELEMENTS = g_currentModDirectory .. "gui/ui_elements.png"
}
local InGameMapExtension_mt = Class(InGameMapExtension)

function InGameMapExtension.new(precisionFarming, customMt)
	local self = setmetatable({}, customMt or InGameMapExtension_mt)
	local uiScale = g_gameSettings:getValue("uiScale")
	local width, height = getNormalizedScreenValues(120 * uiScale, 6 * uiScale)
	local gradientOverlay = Overlay.new(InGameMapExtension.GUI_ELEMENTS, 0, 0, width, height)

	gradientOverlay:setUVs(g_colorBgUVs)
	gradientOverlay:setColor(1, 1, 1, 1)

	self.gradientElement = HUDElement.new(gradientOverlay)
	width, height = getNormalizedScreenValues(122 * uiScale, 8 * uiScale)
	local gradientOverlayBackground = Overlay.new(g_baseUIFilename, 0, 0, width, height)

	gradientOverlayBackground:setUVs(g_colorBgUVs)
	gradientOverlayBackground:setColor(0, 0, 0, 0.6)

	self.gradientBackgroundElement = HUDElement.new(gradientOverlayBackground)
	self.labelPositionsByState = {
		[IngameMap.STATE_MINIMAP_ROUND] = {
			labelOffset = {
				getNormalizedScreenValues(0, 15 * uiScale)
			},
			labelTextSize = {
				getNormalizedScreenValues(0, 15 * uiScale)
			},
			gradientOffset = {
				getNormalizedScreenValues(0, 40 * uiScale)
			},
			labelXAlignment = RenderText.ALIGN_CENTER,
			gradientXAlignment = RenderText.ALIGN_CENTER
		},
		[IngameMap.STATE_MINIMAP_SQUARE] = {
			labelOffset = {
				getNormalizedScreenValues(18 * uiScale, 15 * uiScale)
			},
			labelTextSize = {
				getNormalizedScreenValues(0, 15 * uiScale)
			},
			gradientOffset = {
				getNormalizedScreenValues(0, 30 * uiScale)
			},
			labelXAlignment = RenderText.ALIGN_LEFT,
			gradientXAlignment = RenderText.ALIGN_CENTER
		},
		[IngameMap.STATE_MAP] = {
			labelOffset = {
				getNormalizedScreenValues(18 * uiScale, 15 * uiScale)
			},
			labelTextSize = {
				getNormalizedScreenValues(0, 15 * uiScale)
			},
			gradientOffset = {
				getNormalizedScreenValues(20 * uiScale, 20 * uiScale)
			},
			labelXAlignment = RenderText.ALIGN_LEFT,
			gradientXAlignment = RenderText.ALIGN_LEFT
		}
	}
	self.minimapSoilStateOverlay = createDensityMapVisualizationOverlay("soilStateOverlay", 1024, 1024)
	self.minimapSoilStateOverlayIsReady = nil
	self.minimapSoilStateOverlayIsReadyForDisplay = nil

	precisionFarming:registerVisualizationOverlay(self.minimapSoilStateOverlay)

	self.smoothedMapZoomLevel = 1
	self.smoothedMapZoomTargetLevel = 1
	self.isColorBlindMode = g_gameSettings:getValue(GameSettings.SETTING.USE_COLORBLIND_MODE) or false
	self.precisionFarming = precisionFarming
	self.inGameMap = nil

	g_messageCenter:subscribe(MessageType.SETTING_CHANGED[GameSettings.SETTING.USE_COLORBLIND_MODE], self.onColorBlindModeChanged, self)

	return self
end

function InGameMapExtension:unloadMapData()
end

function InGameMapExtension:delete()
	if self.minimapSoilStateOverlay ~= nil then
		delete(self.minimapSoilStateOverlay)
	end

	self.gradientElement:delete()
	self.gradientBackgroundElement:delete()
	g_messageCenter:unsubscribeAll(self)
end

function InGameMapExtension:update(dt)
	local valueMaps = self.precisionFarming:getValueMaps()
	local requiredValueMap, requiredValueMapSelected = nil

	for i = 1, #valueMaps do
		local valueMap = valueMaps[i]
		local requireDisplay, isSelected = valueMap:getRequireMinimapDisplay()

		if requireDisplay then
			if requiredValueMap == nil then
				requiredValueMap = valueMap
				requiredValueMapSelected = isSelected
			elseif not requiredValueMapSelected and isSelected then
				requiredValueMapSelected = isSelected
				requiredValueMap = valueMap
			end
		end
	end

	if requiredValueMap ~= nil and (self.inGameMap == nil or self.inGameMap.isVisible and self.inGameMap.state ~= IngameMap.STATE_OFF) then
		if self.minimapSoilStateOverlayIsReady == nil or self.minimapSoilStateOverlayIsReady == true then
			local requiredFilter = requiredValueMap:getMinimapValueFilter()
			local requiresUpdate = requiredValueMap:getMinimapRequiresUpdate() or g_server == nil

			if self.lastValueMap ~= requiredValueMap then
				self.minimapSoilStateOverlayIsReadyForDisplay = false
			end

			if self.lastValueMap ~= requiredValueMap or self.lastValueMapFilter ~= requiredFilter or requiresUpdate then
				local updateTimeLimit = requiredValueMap:getMinimapUpdateTimeLimit()

				if g_server == nil then
					updateTimeLimit = 0.15
				end

				setDensityMapVisualizationOverlayUpdateTimeLimit(self.minimapSoilStateOverlay, updateTimeLimit)
				requiredValueMap:buildOverlay(self.minimapSoilStateOverlay, requiredFilter, self.isColorBlindMode, true)
				generateDensityMapVisualizationOverlay(self.minimapSoilStateOverlay)

				self.minimapSoilStateOverlayIsReady = false

				requiredValueMap:setMinimapRequiresUpdate(false)

				self.lastValueMap = requiredValueMap
				self.lastValueMapFilter = requiredFilter
			end
		end

		if self.minimapSoilStateOverlayIsReady == false and getIsDensityMapVisualizationOverlayReady(self.minimapSoilStateOverlay) then
			self.minimapSoilStateOverlayIsReady = true
			self.minimapSoilStateOverlayIsReadyForDisplay = true
		end

		self.smoothedMapZoomTargetLevel = requiredValueMap:getMinimapZoomFactor()
	else
		self.minimapSoilStateOverlayIsReady = nil
		self.minimapSoilStateOverlayIsReadyForDisplay = false
		self.lastValueMap = nil
		self.lastValueMapFilter = nil
		self.smoothedMapZoomTargetLevel = 1
	end

	if self.smoothedMapZoomLevel ~= self.smoothedMapZoomTargetLevel then
		local dir = MathUtil.sign(self.smoothedMapZoomTargetLevel - self.smoothedMapZoomLevel)
		local limit = dir == 1 and math.min or math.max
		self.smoothedMapZoomLevel = limit(self.smoothedMapZoomLevel + dt * 0.001 * dir * 2, self.smoothedMapZoomTargetLevel)
	end
end

function InGameMapExtension:updatePrecisionFarmingOverlays()
	if self.lastValueMap ~= nil then
		self.lastValueMap:setMinimapRequiresUpdate(true)
	end
end

function InGameMapExtension:onColorBlindModeChanged(isColorBlindMode)
	self.isColorBlindMode = isColorBlindMode
	self.minimapSoilStateOverlayIsReady = nil
	self.lastValueMap = nil
	self.lastValueMapFilter = nil
end

function InGameMapExtension:overwriteGameFunctions(pfModule)
	pfModule:overwriteGameFunction(IngameMap, "loadMap", function (superFunc, inGameMap, ...)
		self.inGameMap = inGameMap

		superFunc(inGameMap, ...)
	end)
	pfModule:overwriteGameFunction(IngameMap, "drawFields", function (superFunc, ingameMap)
		superFunc(ingameMap)

		if not ingameMap.isFullscreen then
			if self.minimapSoilStateOverlayIsReadyForDisplay then
				local width, height = ingameMap.layout:getMapSize()
				local x, y = ingameMap.layout:getMapPosition()
				local px, py = ingameMap.layout:getMapPivot()
				px = px + x
				py = py + y
				x = x + width * 0.25
				y = y + height * 0.25
				px = px - x
				py = py - y

				setOverlayRotation(self.minimapSoilStateOverlay, ingameMap.layout:getMapRotation(), px, py)
				setOverlayColor(self.minimapSoilStateOverlay, 1, 1, 1, math.sqrt(ingameMap.layout:getMapAlpha()))
				renderOverlay(self.minimapSoilStateOverlay, x, y, width * 0.5, height * 0.5)
			end

			if self.lastValueMap ~= nil then
				local additionElement = self.lastValueMap:getMinimapAdditionalElement()

				if additionElement ~= nil then
					local x, y = self.lastValueMap:getMinimapAdditionalElementRealSize()

					if x > 0 and y > 0 then
						local width, height = ingameMap.layout:getMapSize()
						additionElement.overlay.width = x / ingameMap.worldSizeX * width * 0.5
						additionElement.overlay.height = y / ingameMap.worldSizeZ * height * 0.5
					end

					local element = ingameMap.layout.backgroundElement

					if element ~= nil then
						local overlay = element.overlay
						local additionalElementLinkNode = self.lastValueMap:getMinimapAdditionalElementLinkNode()

						if additionalElementLinkNode ~= nil then
							local linkX, _, linkZ = getWorldTranslation(additionalElementLinkNode)
							local objectX = (linkX * 0.5 + ingameMap.worldCenterOffsetX) / ingameMap.worldSizeX
							local objectZ = (linkZ * 0.5 + ingameMap.worldCenterOffsetZ) / ingameMap.worldSizeZ
							local posX, posY, _, _ = ingameMap.layout:getMapObjectPosition(objectX, objectZ, additionElement.overlay.width, additionElement.overlay.height, 0, true)
							additionElement.overlay.x = posX
							additionElement.overlay.y = posY
						else
							additionElement.overlay.x = overlay.x + overlay.width * 0.5 - additionElement.overlay.width * 0.5
							additionElement.overlay.y = overlay.y + overlay.height * 0.5 - additionElement.overlay.height * 0.5
						end
					end

					additionElement:draw()
				end
			end
		end
	end)
	pfModule:overwriteGameFunction(IngameMap, "draw", function (superFunc, ingameMap)
		superFunc(ingameMap)

		if not ingameMap.isVisible then
			return
		end

		local width, height = ingameMap.layout:getMapSize()

		if width == 0 or height == 0 then
			return
		end

		if self.labelPositionsByState[ingameMap.state] == nil then
			return
		end

		if self.lastValueMap ~= nil then
			local element = ingameMap.layout.backgroundElement

			if element ~= nil then
				local overlay = element.overlay
				local label = self.lastValueMap:getMinimapLabel()

				if label ~= nil then
					setTextAlignment(RenderText.ALIGN_LEFT)

					local positions = self.labelPositionsByState[ingameMap.state]
					local offsetX = positions.labelOffset[1]
					local offsetY = positions.labelOffset[2]
					local textSize = positions.labelTextSize[2]
					local align = positions.labelXAlignment
					local tx = overlay.x + offsetX
					local ty = overlay.y + overlay.height - offsetY - textSize

					if align == RenderText.ALIGN_CENTER then
						tx = overlay.x + overlay.width * 0.5

						setTextAlignment(RenderText.ALIGN_CENTER)
					end

					setTextColor(0, 0, 0, 1)
					renderText(tx, ty - 0.0015, textSize, label)
					setTextColor(1, 1, 1, 1)
					renderText(tx, ty, textSize, label)
					setTextAlignment(RenderText.ALIGN_LEFT)
				end

				local gradientUVs = self.lastValueMap:getMinimapGradientUVs(self.isColorBlindMode)
				local gradientLabel = self.lastValueMap:getMinimapGradientLabel()

				if gradientUVs ~= nil and gradientLabel ~= nil then
					local positions = self.labelPositionsByState[ingameMap.state]
					local gradientBackgroundElement = self.gradientBackgroundElement
					gradientBackgroundElement.overlay.x = overlay.x + positions.gradientOffset[1]
					gradientBackgroundElement.overlay.y = overlay.y + positions.gradientOffset[2]

					if positions.gradientXAlignment == RenderText.ALIGN_CENTER then
						gradientBackgroundElement.overlay.x = overlay.x + overlay.width * 0.5 - gradientBackgroundElement.overlay.width * 0.5
					end

					gradientBackgroundElement:draw()

					local gradientElement = self.gradientElement
					gradientElement.overlay.x = gradientBackgroundElement.overlay.x + (gradientBackgroundElement.overlay.width - gradientElement.overlay.width) * 0.5
					gradientElement.overlay.y = gradientBackgroundElement.overlay.y + (gradientBackgroundElement.overlay.height - gradientElement.overlay.height) * 0.5

					gradientElement:draw()
					gradientElement:setUVs(unpack(gradientUVs))
					setTextAlignment(RenderText.ALIGN_CENTER)

					local tx = gradientBackgroundElement.overlay.x + gradientBackgroundElement.overlay.width * 0.5
					local ty = gradientBackgroundElement.overlay.y + gradientBackgroundElement.overlay.height + positions.labelTextSize[2] * 0.3

					setTextColor(0, 0, 0, 1)
					renderText(tx, ty - 0.0015, positions.labelTextSize[2] * 0.85, gradientLabel)
					setTextColor(1, 1, 1, 1)
					renderText(tx, ty, positions.labelTextSize[2] * 0.85, gradientLabel)
				end
			end
		end
	end)
	pfModule:overwriteGameFunction(IngameMapLayoutCircle, "getMapSize", function (superFunc, layout)
		local width, _ = superFunc(layout)
		width = width * self.smoothedMapZoomLevel

		return width, width * g_screenAspectRatio
	end)
	pfModule:overwriteGameFunction(IngameMapLayoutSquare, "getMapSize", function (superFunc, layout)
		local width, _ = superFunc(layout)
		width = width * self.smoothedMapZoomLevel

		return width, width * g_screenAspectRatio
	end)
end
