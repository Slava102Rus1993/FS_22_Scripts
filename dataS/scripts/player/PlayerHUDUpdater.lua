PlayerHUDUpdater = {}
local PlayerHUDUpdater_mt = Class(PlayerHUDUpdater)

function PlayerHUDUpdater.new()
	local self = setmetatable({}, PlayerHUDUpdater_mt)
	self.object = nil
	self.isBale = false
	self.isVehicle = false
	self.isPallet = false
	self.isSplitShape = false
	self.isAnimal = false
	self.fieldBox = g_currentMission.hud.infoDisplay:createBox(KeyValueInfoHUDBox)
	self.objectBox = g_currentMission.hud.infoDisplay:createBox(KeyValueInfoHUDBox)

	return self
end

function PlayerHUDUpdater:delete()
	g_currentMission.hud.infoDisplay:destroyBox(self.fieldBox)
	g_currentMission.hud.infoDisplay:destroyBox(self.objectBox)
end

function PlayerHUDUpdater:update(dt, x, y, z, rotY)
	self:updateFieldInfo(x, z, rotY)

	if self.fieldData ~= nil then
		self:showFieldInfo()
	end

	if self.isVehicle then
		self:showVehicleInfo(self.object)
	elseif self.isBale then
		self:showBaleInfo(self.object)
	elseif self.isPallet then
		self:showPalletInfo(self.object)
	elseif self.isSplitShape then
		self:showSplitShapeInfo(self.object)
	elseif self.isAnimal then
		self:showAnimalInfo(self.object)
	end
end

function PlayerHUDUpdater:setCurrentRaycastTarget(node)
	if self.currentRaycastTarget ~= node then
		self.currentRaycastTarget = node

		self:updateRaycastObject()
	end
end

function PlayerHUDUpdater:updateRaycastObject()
	self.isBale = false
	self.isVehicle = false
	self.isPallet = false
	self.isSplitShape = false
	self.isAnimal = false
	self.object = nil

	if self.currentRaycastTarget == nil then
		return
	end

	local object = g_currentMission:getNodeObject(self.currentRaycastTarget)

	if object == nil then
		if getHasClassId(self.currentRaycastTarget, ClassIds.MESH_SPLIT_SHAPE) then
			self.isSplitShape = true
			self.object = self.currentRaycastTarget

			return
		end

		local husbandryId, animalId = getAnimalFromCollisionNode(self.currentRaycastTarget)

		if husbandryId ~= nil and husbandryId ~= 0 then
			local clusterHusbandry = g_currentMission.husbandrySystem:getClusterHusbandyById(husbandryId)

			if clusterHusbandry ~= nil then
				local cluster = clusterHusbandry:getClusterByAnimalId(animalId)

				if cluster ~= nil then
					self.isAnimal = true
					self.object = cluster

					return
				end
			end
		end

		return
	end

	self.object = object

	if object:isa(Vehicle) then
		if object.isPallet then
			self.isPallet = true
		else
			self.isVehicle = true
		end
	elseif object:isa(Bale) then
		self.isBale = true
	end
end

function PlayerHUDUpdater:convertFarmToName(farm)
	if not g_currentMission.missionDynamicInfo.isMultiplayer then
		return g_i18n:getText("fieldInfo_ownerYou")
	else
		return farm.name
	end
end

function PlayerHUDUpdater:showVehicleInfo(vehicle)
	local name = vehicle:getFullName()
	local farmId = vehicle:getOwnerFarmId()

	if farmId ~= FarmManager.SPECTATOR_FARM_ID then
		local farm = g_farmManager:getFarmById(farmId)
		local box = self.objectBox

		box:clear()
		box:setTitle(name)

		local propertyState = vehicle:getPropertyState()

		if propertyState == Vehicle.PROPERTY_STATE_OWNED then
			box:addLine(g_i18n:getText("fieldInfo_ownedBy"), self:convertFarmToName(farm))
		else
			box:addLine(g_i18n:getText("infohud_rentedBy"), self:convertFarmToName(farm))
		end

		vehicle:showInfo(box)
		box:showNextFrame()
	end
end

function PlayerHUDUpdater:showBaleInfo(bale)
	local farm = g_farmManager:getFarmById(bale:getOwnerFarmId())
	local box = self.objectBox

	box:clear()
	box:setTitle(g_i18n:getText("infohud_bale"))

	if farm ~= nil then
		box:addLine(g_i18n:getText("fieldInfo_ownedBy"), self:convertFarmToName(farm))
	end

	bale:showInfo(box)
	box:showNextFrame()
end

function PlayerHUDUpdater:showPalletInfo(pallet)
	local mass = pallet:getTotalMass()
	local farm = g_farmManager:getFarmById(pallet:getOwnerFarmId())
	local box = self.objectBox

	box:clear()

	if pallet.getInfoBoxTitle ~= nil then
		box:setTitle(pallet:getInfoBoxTitle())
	else
		box:setTitle(g_i18n:getText("infohud_pallet"))
	end

	if farm ~= nil then
		box:addLine(g_i18n:getText("fieldInfo_ownedBy"), self:convertFarmToName(farm))
	end

	box:addLine(g_i18n:getText("infohud_mass"), g_i18n:formatMass(mass))
	pallet:showInfo(box)
	box:showNextFrame()
end

function PlayerHUDUpdater:showSplitShapeInfo(splitShape)
	if not entityExists(splitShape) or not getHasClassId(splitShape, ClassIds.MESH_SPLIT_SHAPE) then
		return
	end

	local splitTypeId = getSplitType(splitShape)

	if splitTypeId == 0 then
		return
	end

	local isSplit = getIsSplitShapeSplit(splitShape)
	local isStatic = getRigidBodyType(splitShape) == RigidBodyType.STATIC

	if isSplit and isStatic then
		return
	end

	local sizeX, sizeY, sizeZ, numConvexes, numAttachments = getSplitShapeStats(splitShape)
	local splitType = g_splitTypeManager:getSplitTypeByIndex(splitTypeId)
	local splitTypeName = splitType and splitType.title
	local length = math.max(sizeX, sizeY, sizeZ)
	local box = self.objectBox

	box:clear()

	if isSplit then
		box:setTitle(g_i18n:getText("infohud_wood"))
	else
		box:setTitle(g_i18n:getText("infohud_tree"))
	end

	if splitTypeName ~= nil then
		box:addLine(g_i18n:getText("infohud_type"), splitTypeName)
	end

	box:addLine(g_i18n:getText("infohud_length"), g_i18n:formatNumber(length, 1) .. " m")

	if g_currentMission:getIsServer() and not isStatic then
		local mass = getMass(splitShape)

		box:addLine(g_i18n:getText("infohud_mass"), g_i18n:formatMass(mass))
	end

	box:showNextFrame()
end

function PlayerHUDUpdater:showAnimalInfo(cluster)
	local box = self.objectBox

	box:clear()
	box:setTitle(g_i18n:getText("infohud_animal"))
	cluster:showInfo(box)
	box:showNextFrame()
end

PlayerHUDUpdater.LIME_REQUIRED_THRESHOLD = 0.25
PlayerHUDUpdater.PLOWING_REQUIRED_THRESHOLD = 0.25
PlayerHUDUpdater.ROLLING_REQUIRED_THRESHOLD = 0.25

function PlayerHUDUpdater:updateFieldInfo(posX, posZ, rotY)
	if self.requestedFieldData then
		return
	end

	local sizeX = 5
	local sizeZ = 5
	local distance = 2
	local dirX, dirZ = MathUtil.getDirectionFromYRotation(rotY)
	local sideX, _, sideZ = MathUtil.crossProduct(dirX, 0, dirZ, 0, 1, 0)
	local startWorldX = posX - sideX * sizeX * 0.5 - dirX * distance
	local startWorldZ = posZ - sideZ * sizeX * 0.5 - dirZ * distance
	local widthWorldX = posX + sideX * sizeX * 0.5 - dirX * distance
	local widthWorldZ = posZ + sideZ * sizeX * 0.5 - dirZ * distance
	local heightWorldX = posX - sideX * sizeX * 0.5 - dirX * (distance + sizeZ)
	local heightWorldZ = posZ - sideZ * sizeX * 0.5 - dirZ * (distance + sizeZ)
	self.requestedFieldData = true

	FSDensityMapUtil.getFieldStatusAsync(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, self.onFieldDataUpdateFinished, self)
end

function PlayerHUDUpdater:onFieldDataUpdateFinished(data)
	if self.requestedFieldData then
		self.fieldData = data
		self.fieldInfoNeedsRebuild = true
	end

	self.requestedFieldData = false
end

function PlayerHUDUpdater:showFieldInfo()
	local data = self.fieldData
	local box = self.fieldBox

	if self.fieldInfoNeedsRebuild then
		box:clear()
		box:setTitle(g_i18n:getText("ui_fieldInfo"))
		self:fieldAddFarmland(data, box)
		self:fieldAddFruit(data, box)
		self:fieldAddFertilization(data, box)
		self:fieldAddWeed(data, box)
		self:fieldAddLime(data, box)
		self:fieldAddPlowing(data, box)
		self:fieldAddRolling(data, box)

		self.fieldInfoNeedsRebuild = false
	end

	box:showNextFrame()
end

function PlayerHUDUpdater:fieldAddFarmland(data, box)
	local farmName = nil
	local ownerFarmId = data.ownerFarmId

	if ownerFarmId == g_currentMission:getFarmId() and ownerFarmId ~= FarmManager.SPECTATOR_FARM_ID then
		farmName = g_i18n:getText("fieldInfo_ownerYou")
	elseif ownerFarmId == AccessHandler.EVERYONE or ownerFarmId == AccessHandler.NOBODY then
		local farmland = g_farmlandManager:getFarmlandById(data.farmlandId)

		if farmland == nil then
			farmName = g_i18n:getText("fieldInfo_ownerNobody")
		else
			local npc = farmland:getNPC()
			farmName = npc ~= nil and npc.title or "Unknown"
		end
	else
		local farm = g_farmManager:getFarmById(ownerFarmId)

		if farm ~= nil then
			farmName = farm.name
		else
			farmName = "Unknown"
		end
	end

	box:addLine(g_i18n:getText("fieldInfo_ownedBy"), farmName)
end

function PlayerHUDUpdater:fieldAddLime(data, box)
	if not Platform.gameplay.useLimeCounter then
		return
	end

	local isRequired = PlayerHUDUpdater.LIME_REQUIRED_THRESHOLD < data.needsLimeFactor

	if isRequired and g_currentMission.missionInfo.limeRequired then
		box:addLine(g_i18n:getText("ui_growthMapNeedsLime"), nil, true)
	end
end

function PlayerHUDUpdater:fieldAddPlowing(data, box)
	local isRequired = data.plowFactor < PlayerHUDUpdater.PLOWING_REQUIRED_THRESHOLD

	if isRequired and g_currentMission.missionInfo.plowingRequiredEnabled then
		box:addLine(g_i18n:getText("ui_growthMapNeedsPlowing"), nil, true)
	end
end

function PlayerHUDUpdater:fieldAddRolling(data, box)
	if not Platform.gameplay.useRolling then
		return
	end

	local isRequired = PlayerHUDUpdater.ROLLING_REQUIRED_THRESHOLD < data.needsRollingFactor

	if isRequired then
		box:addLine(g_i18n:getText("ui_growthMapNeedsRolling"), nil, true)
	end
end

function PlayerHUDUpdater:fieldAddFertilization(data, box)
	local fertilizationFactor = data.fertilizerFactor

	if fertilizationFactor >= 0 then
		box:addLine(g_i18n:getText("ui_growthMapFertilized"), string.format("%d %%", fertilizationFactor * 100))
	end
end

function PlayerHUDUpdater:fieldAddWeed(data, box)
	if g_currentMission.missionInfo.weedsEnabled then
		local weedSystem = g_currentMission.weedSystem
		local fieldInfoStates = weedSystem:getFieldInfoStates()
		local maxState = nil
		local maxPixels = 0

		for state, pixels in pairs(data.weed) do
			if maxPixels < pixels then
				maxState = state
				maxPixels = pixels
			end
		end

		if maxState == nil then
			return
		end

		local toolName = nil
		local fruitTypeIndex = data.fruitTypeMax
		local fruitGrowthState = data.fruitStateMax
		local fruitTypeDesc = nil

		if fruitTypeIndex ~= nil then
			fruitTypeDesc = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)
		end

		if fruitTypeIndex == nil or fruitGrowthState < fruitTypeDesc.minHarvestingGrowthState and fruitGrowthState <= fruitTypeDesc.maxWeederState then
			local weederReplacements = weedSystem:getWeederReplacements(false)
			local weed = weederReplacements.weed
			local targetState = weed.replacements[maxState]

			if targetState == 0 then
				toolName = g_i18n:getText("weed_destruction_weeder")
			end
		end

		if toolName == nil and (fruitTypeIndex == nil or fruitGrowthState < fruitTypeDesc.minHarvestingGrowthState and fruitGrowthState <= fruitTypeDesc.maxWeederHoeState) then
			local hoeReplacements = weedSystem:getWeederReplacements(true)
			local weed = hoeReplacements.weed
			local targetState = weed.replacements[maxState]

			if targetState == 0 then
				toolName = g_i18n:getText("weed_destruction_hoe")
			end
		end

		if toolName == nil and (fruitTypeIndex == nil or fruitGrowthState < fruitTypeDesc.minHarvestingGrowthState) then
			toolName = g_i18n:getText("weed_destruction_herbicide")
		end

		local title = fieldInfoStates[maxState]

		box:addLine(title, toolName or "-", true)
	end
end

function PlayerHUDUpdater:fieldAddFruit(data, box)
	local fruitTypeIndex = data.fruitTypeMax
	local fruitGrowthState = data.fruitStateMax

	if fruitTypeIndex == nil then
		return
	end

	local fruitType = g_fruitTypeManager:getFruitTypeByIndex(fruitTypeIndex)

	box:addLine(g_i18n:getText("statistic_fillType"), fruitType.fillType.title)

	local witheredState = fruitType.maxHarvestingGrowthState + 1

	if fruitType.maxPreparingGrowthState >= 0 then
		witheredState = fruitType.maxPreparingGrowthState + 1
	end

	local maxGrowingState = fruitType.minHarvestingGrowthState - 1

	if fruitType.minPreparingGrowthState >= 0 then
		maxGrowingState = math.min(maxGrowingState, fruitType.minPreparingGrowthState - 1)
	end

	local text = nil
	local isGrowing = false

	if fruitGrowthState == fruitType.cutState then
		text = g_i18n:getText("ui_growthMapCut")
	elseif fruitGrowthState == witheredState then
		text = g_i18n:getText("ui_growthMapWithered")
	elseif fruitGrowthState > 0 and fruitGrowthState <= maxGrowingState then
		text = g_i18n:getText("ui_growthMapGrowing")
		isGrowing = true
	elseif fruitType.minPreparingGrowthState >= 0 and fruitType.minPreparingGrowthState <= fruitGrowthState and fruitGrowthState <= fruitType.maxPreparingGrowthState then
		text = g_i18n:getText("ui_growthMapReadyToPrepareForHarvest")
		isGrowing = true
	elseif fruitType.minHarvestingGrowthState <= fruitGrowthState and fruitGrowthState <= fruitType.maxHarvestingGrowthState then
		text = g_i18n:getText("ui_growthMapReadyToHarvest")
		isGrowing = true
	end

	if text ~= nil then
		box:addLine(g_i18n:getText("ui_mapOverviewGrowth"), text)

		if isGrowing then
			local sprayFactor = data.fertilizerFactor
			local plowFactor = data.plowFactor
			local limeFactor = 1
			local weedFactor = data.weedFactor
			local stubbleFactor = 1
			local rollerFactor = 1
			local missionInfo = g_currentMission.missionInfo

			if not missionInfo.plowingRequiredEnabled then
				plowFactor = 1
			end

			if missionInfo.limeRequired and Platform.gameplay.useLimeCounter then
				limeFactor = 1 - data.needsLimeFactor
			end

			if not missionInfo.weedsEnabled then
				weedFactor = 1
			end

			if Platform.gameplay.useRolling then
				rollerFactor = 1 - data.needsRollingFactor
			end

			if Platform.gameplay.useStubbleShred then
				stubbleFactor = data.stubbleFactor
			end

			local harvestMultiplier = g_currentMission:getHarvestScaleMultiplier(fruitTypeIndex, sprayFactor, plowFactor, limeFactor, weedFactor, stubbleFactor, rollerFactor, 0) - 1
			harvestMultiplier = math.ceil(harvestMultiplier * 100)

			box:addLine(g_i18n:getText("fieldInfo_yieldBonus"), string.format("+ %d %%", harvestMultiplier))
		end
	end
end
