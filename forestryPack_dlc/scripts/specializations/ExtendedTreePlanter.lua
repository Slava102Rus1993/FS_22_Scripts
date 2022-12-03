local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

ExtendedTreePlanter = {
	MOD_DIRECTORY = g_currentModDirectory,
	MOD_NAME = g_currentModName,
	SPEC_NAME = g_currentModName .. ".extendedTreePlanter",
	SPEC_TABLE_NAME = "spec_" .. g_currentModName .. ".extendedTreePlanter"
}

source(g_currentModDirectory .. "scripts/specializations/events/ExtendedTreePlanterCreateTreeEvent.lua")

function ExtendedTreePlanter.prerequisitesPresent(specializations)
	return true
end

function ExtendedTreePlanter.initSpecialization()
	local schema = Vehicle.xmlSchema

	schema:setXMLSpecializationType("ExtendedTreePlanter")
	schema:register(XMLValueType.STRING, "vehicle.treePlanter.saplingNodes.treeTypes.treeType(?)#name", "Name of tree type")
	schema:register(XMLValueType.STRING, "vehicle.treePlanter.saplingNodes.treeTypes.treeType(?)#filename", "Path of external i3d file that is loaded and linked to the sapling nodes (if not defined, firest tree type stage is used)")
	schema:register(XMLValueType.NODE_INDEX, "vehicle.treePlanter.saplingNodes.saplingNode(?)#node", "Link node for tree sapling (will be hidden based on fill level)")
	schema:register(XMLValueType.STRING, "vehicle.treePlanter.plantAnimation#name", "Name of plant animation")
	schema:register(XMLValueType.FLOAT, "vehicle.treePlanter.plantAnimation#speedScale", "Speed scale of animation", 1)
	schema:register(XMLValueType.STRING, "vehicle.treePlanter.magazineAnimation#name", "Name of magazine animation (updated based on fill level)")
	schema:register(XMLValueType.FLOAT, "vehicle.treePlanter.magazineAnimation#speedScale", "Speed scale of animation", 1)
	schema:register(XMLValueType.INT, "vehicle.treePlanter.magazineAnimation#numRows", "Number of rows on the magazine", 1)
	schema:setXMLSpecializationType()

	local schemaSavegame = Vehicle.xmlSchemaSavegame

	schemaSavegame:register(XMLValueType.STRING, string.format("vehicles.vehicle(?).%s#currentTreeType", ExtendedTreePlanter.SPEC_NAME), "Name of currently loaded tree type")
end

function ExtendedTreePlanter.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "updateTreePlanterFillLevel", ExtendedTreePlanter.updateTreePlanterFillLevel)
	SpecializationUtil.registerFunction(vehicleType, "setTreePlanterTreeTypeIndex", ExtendedTreePlanter.setTreePlanterTreeTypeIndex)
	SpecializationUtil.registerFunction(vehicleType, "onTreePlanterSaplingLoaded", ExtendedTreePlanter.onTreePlanterSaplingLoaded)
end

function ExtendedTreePlanter.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "createTree", ExtendedTreePlanter.createTree)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "unloadFillUnits", ExtendedTreePlanter.unloadFillUnits)
end

function ExtendedTreePlanter.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", ExtendedTreePlanter)
	SpecializationUtil.registerEventListener(vehicleType, "onDelete", ExtendedTreePlanter)
	SpecializationUtil.registerEventListener(vehicleType, "onReadStream", ExtendedTreePlanter)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteStream", ExtendedTreePlanter)
	SpecializationUtil.registerEventListener(vehicleType, "onReadUpdateStream", ExtendedTreePlanter)
	SpecializationUtil.registerEventListener(vehicleType, "onWriteUpdateStream", ExtendedTreePlanter)
	SpecializationUtil.registerEventListener(vehicleType, "onUpdateTick", ExtendedTreePlanter)
	SpecializationUtil.registerEventListener(vehicleType, "onDraw", ExtendedTreePlanter)
	SpecializationUtil.registerEventListener(vehicleType, "onFillUnitFillLevelChanged", ExtendedTreePlanter)
	SpecializationUtil.registerEventListener(vehicleType, "onFillUnitIsFillingStateChanged", ExtendedTreePlanter)
	SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", ExtendedTreePlanter)
end

function ExtendedTreePlanter:onLoad(savegame)
	local spec = self[ExtendedTreePlanter.SPEC_TABLE_NAME]
	spec.currentTreeTypeIndex = nil
	spec.treeTypeFilenames = {}

	self.xmlFile:iterate("vehicle.treePlanter.saplingNodes.treeTypes.treeType", function (index, key)
		local name = self.xmlFile:getValue(key .. "#name")
		local treeTypeDesc = g_treePlantManager:getTreeTypeDescFromName(name)

		if treeTypeDesc ~= nil then
			local filename = self.xmlFile:getValue(key .. "#filename")

			if filename ~= nil then
				filename = Utils.getFilename(filename, self.baseDirectory)
			else
				filename = treeTypeDesc.treeFilenames[1]
			end

			spec.treeTypeFilenames[treeTypeDesc.index] = filename
		end
	end)

	spec.saplingNodes = {}

	self.xmlFile:iterate("vehicle.treePlanter.saplingNodes.saplingNode", function (index, key)
		local node = self.xmlFile:getValue(key .. "#node", nil, self.components, self.i3dMappings)

		if node ~= nil then
			table.insert(spec.saplingNodes, node)
		end
	end)

	spec.plantAnimation = {
		name = self.xmlFile:getValue("vehicle.treePlanter.plantAnimation#name"),
		speedScale = self.xmlFile:getValue("vehicle.treePlanter.plantAnimation#speedScale", 1)
	}
	spec.magazineAnimation = {
		name = self.xmlFile:getValue("vehicle.treePlanter.magazineAnimation#name"),
		speedScale = self.xmlFile:getValue("vehicle.treePlanter.magazineAnimation#speedScale", 1),
		numRows = self.xmlFile:getValue("vehicle.treePlanter.magazineAnimation#numRows", 1)
	}
	spec.texts = {
		plantTree = g_i18n:getText("action_plantTree", self.customEnvironment),
		warningTreePlanterNoGroundContact = g_i18n:getText("warning_treePlanterNoGroundContact", self.customEnvironment)
	}
	spec.dirtyFlag = self:getNextDirtyFlag()

	if savegame ~= nil then
		local treeTypeName = savegame.xmlFile:getValue(string.format("%s.%s#currentTreeType", savegame.key, ExtendedTreePlanter.SPEC_NAME))

		if treeTypeName ~= nil then
			self:setTreePlanterTreeTypeIndex(g_treePlantManager:getTreeTypeIndexFromName(treeTypeName))
		end
	end

	if not self.isClient then
		SpecializationUtil.removeEventListener(self, "onUpdateTick", ExtendedTreePlanter)
	end
end

function ExtendedTreePlanter:saveToXMLFile(xmlFile, key, usedModNames)
	local spec = self[ExtendedTreePlanter.SPEC_TABLE_NAME]

	if spec.currentTreeTypeIndex ~= nil then
		local treeTypeName = g_treePlantManager:getTreeTypeNameFromIndex(spec.currentTreeTypeIndex)

		if treeTypeName ~= nil then
			xmlFile:setValue(key .. "#currentTreeType", treeTypeName)
		end
	end
end

function ExtendedTreePlanter:onDelete()
	local spec = self[ExtendedTreePlanter.SPEC_TABLE_NAME]

	if spec.saplingSharedLoadRequestId ~= nil then
		g_i3DManager:releaseSharedI3DFile(spec.saplingSharedLoadRequestId)
	end
end

function ExtendedTreePlanter:onReadStream(streamId, connection)
	if streamReadBool(streamId) then
		self:setTreePlanterTreeTypeIndex(streamReadInt32(streamId))
	end

	if streamReadBool(streamId) then
		self.spec_treePlanter.lastTreePos = {
			streamReadFloat32(streamId),
			streamReadFloat32(streamId),
			streamReadFloat32(streamId)
		}
	end
end

function ExtendedTreePlanter:onWriteStream(streamId, connection)
	local spec = self[ExtendedTreePlanter.SPEC_TABLE_NAME]

	if streamWriteBool(streamId, spec.currentTreeTypeIndex ~= nil) then
		streamWriteInt32(streamId, spec.currentTreeTypeIndex)
	end

	local spec_treePlanter = self.spec_treePlanter

	if streamWriteBool(streamId, spec_treePlanter.lastTreePos ~= nil) then
		streamWriteFloat32(streamId, spec_treePlanter.lastTreePos[1])
		streamWriteFloat32(streamId, spec_treePlanter.lastTreePos[2])
		streamWriteFloat32(streamId, spec_treePlanter.lastTreePos[3])
	end
end

function ExtendedTreePlanter:onReadUpdateStream(streamId, timestamp, connection)
	if connection:getIsServer() and streamReadBool(streamId) then
		self:setTreePlanterTreeTypeIndex(streamReadInt32(streamId))
	end
end

function ExtendedTreePlanter:onWriteUpdateStream(streamId, connection, dirtyMask)
	if not connection:getIsServer() then
		local spec = self[ExtendedTreePlanter.SPEC_TABLE_NAME]

		if streamWriteBool(streamId, bitAND(dirtyMask, spec.dirtyFlag) ~= 0) then
			streamWriteInt32(streamId, spec.currentTreeTypeIndex)
		end
	end
end

function ExtendedTreePlanter:onUpdateTick(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	local specPlanter = self.spec_treePlanter

	if specPlanter.lastTreePos ~= nil then
		local spec = self[ExtendedTreePlanter.SPEC_TABLE_NAME]
		local actionEvent = spec.actionEvents[InputAction.IMPLEMENT_EXTRA2]

		if actionEvent ~= nil then
			local x, y, z = getWorldTranslation(specPlanter.node)
			local distance = MathUtil.vector3Length(x - specPlanter.lastTreePos[1], y - specPlanter.lastTreePos[2], z - specPlanter.lastTreePos[3])

			g_inputBinding:setActionEventActive(actionEvent.actionEventId, specPlanter.minDistance < distance and self:getFillUnitFillLevel(self.spec_treePlanter.fillUnitIndex) > 0)
		end
	end
end

function ExtendedTreePlanter:onDraw(isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
	local spec = self[ExtendedTreePlanter.SPEC_TABLE_NAME]

	if spec.currentTreeTypeIndex ~= nil and self:getFillUnitFillLevel(self.spec_treePlanter.fillUnitIndex) > 0 and spec.extraPrintText ~= nil then
		g_currentMission:addExtraPrintText(spec.extraPrintText)
	end
end

function ExtendedTreePlanter:onFillUnitFillLevelChanged(fillUnitIndex, fillLevelDelta, fillTypeIndex, toolType, fillPositionData, appliedDelta)
	if fillUnitIndex == self.spec_treePlanter.fillUnitIndex then
		self:updateTreePlanterFillLevel()
	end
end

function ExtendedTreePlanter:onFillUnitIsFillingStateChanged(isFilling)
	if isFilling then
		local trigger = self.spec_fillUnit.fillTrigger.currentTrigger

		if trigger ~= nil and trigger.sourceObject ~= nil and trigger.sourceObject.getTreeType ~= nil then
			self:setTreePlanterTreeTypeIndex(g_treePlantManager:getTreeTypeIndexFromName(trigger.sourceObject:getTreeType()))
		end
	end
end

function ExtendedTreePlanter:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
	if self.isClient then
		local spec = self[ExtendedTreePlanter.SPEC_TABLE_NAME]

		self:clearActionEventsTable(spec.actionEvents)

		spec.unloadActionEventId = nil

		if isActiveForInputIgnoreSelection then
			local _, actionEventId = self:addPoweredActionEvent(spec.actionEvents, InputAction.IMPLEMENT_EXTRA2, self, ExtendedTreePlanter.actionEventPlant, false, true, false, true, nil)

			g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
			g_inputBinding:setActionEventText(actionEventId, spec.texts.plantTree)

			if self.spec_fillUnit ~= nil and self.spec_fillUnit.unloading ~= nil then
				self:clearActionEventsTable(self.spec_fillUnit.actionEvents)

				self.spec_fillUnit.unloadActionEventId = nil
				_, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.UNLOAD, self, FillUnit.actionEventUnload, false, true, false, true, nil)

				g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_NORMAL)
				g_inputBinding:setActionEventActive(actionEventId, self:getFillUnitFillLevel(self.spec_treePlanter.fillUnitIndex) > 0)

				spec.unloadActionEventId = actionEventId
			end
		end
	end
end

function ExtendedTreePlanter:actionEventPlant(actionName, inputValue, callbackState, isAnalog)
	local specPlanter = self.spec_treePlanter
	local spec = self[ExtendedTreePlanter.SPEC_TABLE_NAME]

	if specPlanter.hasGroundContact then
		if g_treePlantManager:canPlantTree() then
			local x, y, z = getWorldTranslation(specPlanter.node)

			if g_currentMission.accessHandler:canFarmAccessLand(self:getActiveFarm(), x, z) then
				if not PlacementUtil.isInsideRestrictedZone(g_currentMission.restrictedZones, x, y, z, true) then
					self:createTree()
				else
					g_currentMission:showBlinkingWarning(g_i18n:getText("warning_actionNotAllowedHere"))
				end
			else
				g_currentMission:showBlinkingWarning(g_i18n:getText("warning_youDontHaveAccessToThisLand"))
			end
		else
			g_currentMission:showBlinkingWarning(g_i18n:getText("warning_tooManyTrees"))
		end
	else
		g_currentMission:showBlinkingWarning(spec.texts.warningTreePlanterNoGroundContact)
	end
end

function ExtendedTreePlanter:updateTreePlanterFillLevel(onLoad)
	local fillLevel = self:getFillUnitFillLevel(self.spec_treePlanter.fillUnitIndex)
	local capacity = self:getFillUnitCapacity(self.spec_treePlanter.fillUnitIndex)
	local spec = self[ExtendedTreePlanter.SPEC_TABLE_NAME]

	for i = 1, #spec.saplingNodes do
		local node = spec.saplingNodes[i]

		setVisibility(node, i <= MathUtil.round(fillLevel))
		I3DUtil.setShaderParameterRec(node, "hideByIndex", capacity - fillLevel, 0, 0, 0)
	end

	if spec.magazineAnimation.name ~= nil then
		local targetAnimationTime = math.ceil((fillLevel - 1) / capacity * spec.magazineAnimation.numRows) / spec.magazineAnimation.numRows
		local animationTime = self:getAnimationTime(spec.magazineAnimation.name)

		if targetAnimationTime ~= animationTime then
			self:setAnimationStopTime(spec.magazineAnimation.name, targetAnimationTime)
			self:playAnimation(spec.magazineAnimation.name, spec.magazineAnimation.speedScale * MathUtil.sign(targetAnimationTime - animationTime), animationTime, true)

			if onLoad then
				AnimatedVehicle.updateAnimationByName(self, spec.magazineAnimation.name, 999999, true)
			end
		end
	end

	if spec.unloadActionEventId ~= nil then
		g_inputBinding:setActionEventActive(spec.unloadActionEventId, fillLevel > 0)
	end
end

function ExtendedTreePlanter:setTreePlanterTreeTypeIndex(treeTypeIndex)
	local spec = self[ExtendedTreePlanter.SPEC_TABLE_NAME]

	if treeTypeIndex ~= nil and treeTypeIndex ~= spec.currentTreeTypeIndex then
		for i = 1, #spec.saplingNodes do
			for j = 1, getNumOfChildren(spec.saplingNodes[i]) do
				delete(getChildAt(spec.saplingNodes[i], 0))
			end
		end

		if spec.saplingSharedLoadRequestId ~= nil then
			g_i3DManager:releaseSharedI3DFile(spec.saplingSharedLoadRequestId)
		end

		local filename = spec.treeTypeFilenames[treeTypeIndex]

		if filename ~= nil then
			spec.saplingSharedLoadRequestId = g_i3DManager:loadSharedI3DFileAsync(filename, false, false, self.onTreePlanterSaplingLoaded, self, {})
		end

		spec.currentTreeTypeIndex = treeTypeIndex
		local treeTypeDesc = g_treePlantManager:getTreeTypeDescFromIndex(treeTypeIndex)

		if treeTypeDesc ~= nil then
			spec.extraPrintText = string.format("%s: %s", g_i18n:getText("configuration_treeType", self.customEnvironment), g_i18n:getText(treeTypeDesc.nameI18N, self.customEnvironment))
		end

		if self.isServer then
			self:raiseDirtyFlags(spec.dirtyFlag)
		end
	end
end

function ExtendedTreePlanter:onTreePlanterSaplingLoaded(i3dNode, failedReason, args)
	if i3dNode ~= 0 then
		local sourceSapling = getChildAt(i3dNode, 0)
		local spec = self[ExtendedTreePlanter.SPEC_TABLE_NAME]

		for i = 1, #spec.saplingNodes do
			local sapling = clone(sourceSapling, false, false, false)

			link(spec.saplingNodes[i], sapling)
		end

		self:updateTreePlanterFillLevel(true)
		delete(i3dNode)
	end
end

function ExtendedTreePlanter:createTree(superFunc, noEventSend)
	local specPlanter = self.spec_treePlanter
	local spec = self[ExtendedTreePlanter.SPEC_TABLE_NAME]

	if self.isServer then
		local treeTypeIndex = self[ExtendedTreePlanter.SPEC_TABLE_NAME].currentTreeTypeIndex

		if specPlanter.mountedSaplingPallet ~= nil then
			treeTypeIndex = g_treePlantManager:getTreeTypeIndexFromName(specPlanter.mountedSaplingPallet:getTreeType()) or treeTypeIndex
		end

		if treeTypeIndex ~= nil then
			local x, _, z = getWorldTranslation(specPlanter.node)
			local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
			local yRot = math.random() * 2 * math.pi

			g_treePlantManager:plantTree(treeTypeIndex, x, y, z, 0, yRot, 0, 0)

			local stats = g_farmManager:getFarmById(self:getActiveFarm()).stats

			if not self:getIsAIActive() then
				local fillLevelChange = -0.9999

				if self:getFillUnitFillLevel(specPlanter.fillUnitIndex) < 1.5 then
					fillLevelChange = -math.huge
				end

				self:addFillUnitFillLevel(self:getOwnerFarmId(), specPlanter.fillUnitIndex, fillLevelChange, self:getFillUnitFillType(specPlanter.fillUnitIndex), ToolType.UNDEFINED)
			end

			stats:updateStats("plantedTreeCount", 1)
		end
	end

	if specPlanter.lastTreePos ~= nil then
		specPlanter.lastTreePos[1], specPlanter.lastTreePos[2], specPlanter.lastTreePos[3] = getWorldTranslation(specPlanter.node)
	else
		specPlanter.lastTreePos = {
			getWorldTranslation(specPlanter.node)
		}
	end

	if spec.plantAnimation.name ~= nil then
		self:setAnimationTime(spec.plantAnimation.name, 0, true)
		self:playAnimation(spec.plantAnimation.name, spec.plantAnimation.speedScale, 0, true)
	end

	ExtendedTreePlanterCreateTreeEvent.sendEvent(self, noEventSend)
end

function ExtendedTreePlanter:unloadFillUnits(ignoreWarning)
	if not self.isServer then
		g_client:getServerConnection():sendEvent(FillUnitUnloadEvent.new(self))
	else
		local spec = self.spec_fillUnit

		if spec.unloadingFillUnitsRunning then
			return
		end

		local unloadingPlaces = spec.unloading
		local places = {}

		for _, unloading in ipairs(unloadingPlaces) do
			local node = unloading.node
			local ox, oy, oz = unpack(unloading.offset)
			local x, y, z = localToWorld(node, ox - unloading.width * 0.5, oy, oz)
			local place = {
				startZ = z,
				startY = y,
				startX = x
			}
			place.rotX, place.rotY, place.rotZ = getWorldRotation(node)
			place.dirX, place.dirY, place.dirZ = localDirectionToWorld(node, 1, 0, 0)
			place.dirPerpX, place.dirPerpY, place.dirPerpZ = localDirectionToWorld(node, 0, 0, 1)
			place.yOffset = 1
			place.maxWidth = math.huge
			place.maxLength = math.huge
			place.maxHeight = math.huge
			place.width = unloading.width

			table.insert(places, place)
		end

		local usedPlaces = {}
		local success = true
		local availablePallets = {}
		local unloadingTasks = {}

		for k, fillUnit in ipairs(self:getFillUnits()) do
			local fillLevel = self:getFillUnitFillLevel(k)
			local fillTypeIndex = self:getFillUnitFillType(k)
			local fillType = g_fillTypeManager:getFillTypeByIndex(fillTypeIndex)
			local palletFilename = fillType.palletFilename

			if fillType.index == FillType.TREESAPLINGS then
				palletFilename = ExtendedTreePlanter.MOD_DIRECTORY .. "objects/saplingPalletRisutec/saplingPalletRisutec.xml"
			end

			if fillUnit.canBeUnloaded and fillLevel > 0 and palletFilename ~= nil then
				table.insert(unloadingTasks, {
					fillUnitIndex = k,
					fillTypeIndex = fillTypeIndex,
					fillLevel = fillLevel,
					filename = palletFilename
				})
			end
		end

		local function unloadNext()
			local task = unloadingTasks[1]

			if task ~= nil then
				for pallet, _ in pairs(availablePallets) do
					local fillUnitIndex = pallet:getFirstValidFillUnitToFill(task.fillTypeIndex)

					if fillUnitIndex ~= nil then
						local appliedDelta = pallet:addFillUnitFillLevel(self:getOwnerFarmId(), fillUnitIndex, task.fillLevel, task.fillTypeIndex, ToolType.UNDEFINED, nil)

						self:addFillUnitFillLevel(self:getOwnerFarmId(), task.fillUnitIndex, -appliedDelta, task.fillTypeIndex, ToolType.UNDEFINED, nil)

						task.fillLevel = task.fillLevel - appliedDelta

						if pallet:getFillUnitFreeCapacity(fillUnitIndex) <= 0 then
							availablePallets[pallet] = nil
						end
					end
				end

				if task.fillLevel > 0 then
					local function asyncCallback(_, vehicle, vehicleLoadState, arguments)
						if vehicleLoadState == VehicleLoadingUtil.VEHICLE_LOAD_OK then
							vehicle:emptyAllFillUnits(true)

							availablePallets[vehicle] = true

							unloadNext()
						end
					end

					local size = StoreItemUtil.getSizeValues(task.filename, "vehicle", 0, {})
					local x, y, z, place, width, _ = PlacementUtil.getPlace(places, size, usedPlaces, true, true, true)

					if x == nil then
						success = false

						if (ignoreWarning == nil or not ignoreWarning) and not success then
							g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, spec.texts.unloadNoSpace)
						end

						return
					end

					PlacementUtil.markPlaceUsed(usedPlaces, place, width)

					local location = {
						x = x,
						y = y,
						z = z,
						yRot = place.rotY
					}
					local configurations = {}
					local treeTypeIndex = self[ExtendedTreePlanter.SPEC_TABLE_NAME].currentTreeTypeIndex

					if treeTypeIndex ~= nil then
						local treeType = g_treePlantManager:getTreeTypeDescFromIndex(treeTypeIndex)
						local storeItem = g_storeManager:getItemByXMLFilename(task.filename)

						if storeItem ~= nil and storeItem.configurations ~= nil then
							local treeSaplingConfigs = storeItem.configurations.treeSaplingType

							if treeSaplingConfigs ~= nil then
								local xmlFile = XMLFile.load("vehicleXML", task.filename, Vehicle.xmlSchema)

								for i = 1, #treeSaplingConfigs do
									local treeTypeName = xmlFile:getValue(string.format("vehicle.treeSaplingPallet.treeSaplingTypeConfigurations.treeSaplingTypeConfiguration(%d)#treeType", i - 1))

									if treeTypeName ~= nil and treeTypeName:upper() == treeType.name then
										configurations.treeSaplingType = i
									end
								end

								xmlFile:delete()
							end
						end
					end

					VehicleLoadingUtil.loadVehicle(task.filename, location, true, 0, Vehicle.PROPERTY_STATE_OWNED, self:getOwnerFarmId(), configurations, nil, asyncCallback, nil)
				else
					table.remove(unloadingTasks, 1)
					unloadNext()
				end
			end
		end

		unloadNext()
	end
end
