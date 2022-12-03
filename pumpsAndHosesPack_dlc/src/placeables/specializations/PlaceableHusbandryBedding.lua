PlaceableHusbandryBedding = {
	MOD_DIRECTORY = g_currentModDirectory,
	MOD_NAME = g_currentModName,
	prerequisitesPresent = function (specializations)
		return true
	end
}

function PlaceableHusbandryBedding.registerFunctions(placeableType)
	SpecializationUtil.registerFunction(placeableType, "updatePlane", PlaceableHusbandryBedding.updatePlane)
end

function PlaceableHusbandryBedding.registerOverwrittenFunctions(placeableType)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "updateOutput", PlaceableHusbandryBedding.updateOutput)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "updateProduction", PlaceableHusbandryBedding.updateProduction)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "getConditionInfos", PlaceableHusbandryBedding.getConditionInfos)
	SpecializationUtil.registerOverwrittenFunction(placeableType, "updateInfo", PlaceableHusbandryBedding.updateInfo)
end

function PlaceableHusbandryBedding.registerEventListeners(placeableType)
	SpecializationUtil.registerEventListener(placeableType, "onLoad", PlaceableHusbandryBedding)
	SpecializationUtil.registerEventListener(placeableType, "onPostFinalizePlacement", PlaceableHusbandryBedding)
	SpecializationUtil.registerEventListener(placeableType, "onDelete", PlaceableHusbandryBedding)
	SpecializationUtil.registerEventListener(placeableType, "onReadStream", PlaceableHusbandryBedding)
	SpecializationUtil.registerEventListener(placeableType, "onHusbandryAnimalsUpdate", PlaceableHusbandryBedding)
	SpecializationUtil.registerEventListener(placeableType, "onHusbandryFillLevelChanged", PlaceableHusbandryBedding)
end

function PlaceableHusbandryBedding:onLoad(savegame)
	self.spec_husbandryBedding = self[("spec_%s.husbandryBedding"):format(PlaceableHusbandryBedding.MOD_NAME)]
	local spec = self.spec_husbandryBedding
	spec.extendFillType = FillType.STRAW
	spec.inputFillType = FillType.SEPARATED_MANURE
	spec.outputFillType = FillType.MANURE
	local unloadingStation = self.spec_husbandry.unloadingStation

	if unloadingStation ~= nil then
		for _, trigger in ipairs(unloadingStation.unloadTriggers) do
			if trigger.fillTypes[spec.extendFillType] ~= nil then
				trigger.fillTypes[spec.inputFillType] = true
			end
		end

		unloadingStation:updateSupportedFillTypes()
	end

	local storage = self.spec_husbandry.storage

	if storage ~= nil then
		storage.fillTypes[spec.inputFillType] = true
		storage.capacities[spec.inputFillType] = storage.capacities[spec.extendFillType]

		table.insert(storage.sortedFillTypes, spec.inputFillType)

		storage.fillLevels[spec.inputFillType] = 0
		storage.fillLevelsLastSynced[spec.inputFillType] = 0

		table.sort(storage.sortedFillTypes)
	end

	spec.manureFactor = self.xmlFile:getValue("placeable.husbandry.straw.manure#factor", 1)
	spec.isManureActive = self.xmlFile:getValue("placeable.husbandry.straw.manure#active", true)

	if self.isClient then
		local beddingPlane = FillPlane.new()

		if beddingPlane:load(self.components, self.xmlFile, "placeable.husbandry.straw.strawPlane", self.i3dMappings) then
			local linkNode = getParent(beddingPlane.node)
			local node = clone(beddingPlane.node, false, false, false)

			link(linkNode, node)

			if beddingPlane.colorChange then
				FillPlaneUtil.assignDefaultMaterials(node)
				FillPlaneUtil.setFillType(node, spec.inputFillType)
				setShaderParameter(node, "isCustomShape", 1, 0, 0, 0, false)
			end

			beddingPlane.node = node

			beddingPlane:setState(0)

			spec.beddingPlane = beddingPlane
		else
			beddingPlane:delete()
		end
	end

	spec.inputLitersPerHour = 0
	spec.outputLitersPerHour = 0
	spec.info = {
		text = "",
		title = g_i18n:getText("fillType_separatedManure")
	}
end

function PlaceableHusbandryBedding:onDelete()
	local spec = self.spec_husbandryBedding

	if spec == nil then
		return
	end

	if spec.beddingPlane ~= nil then
		spec.beddingPlane:delete()

		spec.beddingPlane = nil
	end
end

function PlaceableHusbandryBedding:onPostFinalizePlacement()
	self:updatePlane()
end

function PlaceableHusbandryBedding:onReadStream(streamId, connection)
	self:updatePlane()
end

function PlaceableHusbandryBedding:updatePlane()
	local spec = self.spec_husbandryBedding

	if spec.beddingPlane ~= nil then
		local capacity = self:getHusbandryCapacity(spec.inputFillType, nil)
		local fillLevel = self:getHusbandryFillLevel(spec.inputFillType, nil)
		local factor = 0

		if capacity > 0 then
			factor = fillLevel / capacity
		end

		spec.beddingPlane:setState(factor)
	end
end

function PlaceableHusbandryBedding:onHusbandryFillLevelChanged(fillTypeIndex, delta)
	local spec = self.spec_husbandryBedding

	if fillTypeIndex == spec.inputFillType then
		self:updatePlane()
	end
end

function PlaceableHusbandryBedding:onHusbandryAnimalsUpdate(clusters)
	local spec = self.spec_husbandryBedding
	spec.inputLitersPerHour = 0
	spec.outputLitersPerHour = 0

	if self:getHusbandryFillLevel(spec.extendFillType) > 0 then
		return
	end

	for _, cluster in ipairs(clusters) do
		local subType = g_currentMission.animalSystem:getSubTypeByIndex(cluster.subTypeIndex)

		if subType ~= nil then
			local straw = subType.input.straw

			if straw ~= nil then
				local age = cluster:getAge()
				local litersPerAnimal = straw:get(age) * 1.5
				local litersPerDay = litersPerAnimal * cluster:getNumAnimals()
				spec.inputLitersPerHour = spec.inputLitersPerHour + litersPerDay / 24
			end

			local manure = subType.output.manure

			if manure ~= nil then
				local age = cluster:getAge()
				local litersPerAnimal = manure:get(age)
				local litersPerDay = litersPerAnimal * cluster:getNumAnimals()
				spec.outputLitersPerHour = spec.outputLitersPerHour + litersPerDay / 24
			end
		end
	end
end

function PlaceableHusbandryBedding:updateProduction(superFunc, foodFactor)
	local factor = superFunc(self, foodFactor)
	local spec = self.spec_husbandryBedding

	if self:getHusbandryFillLevel(spec.extendFillType) > 0 then
		return factor
	end

	if self:getHusbandryFillLevel(spec.inputFillType) > 0 then
		local freeCapacity = self:getHusbandryFreeCapacity(spec.outputFillType)

		if freeCapacity <= 0 then
			factor = factor * 0.8
		end
	end

	return factor
end

function PlaceableHusbandryBedding:updateOutput(superFunc, foodFactor, productionFactor, globalProductionFactor)
	if self.isServer then
		local spec = self.spec_husbandryBedding

		if spec.inputLitersPerHour > 0 then
			local amount = spec.inputLitersPerHour * g_currentMission.environment.timeAdjustment
			local delta = amount - self:removeHusbandryFillLevel(self:getOwnerFarmId(), amount, spec.inputFillType)

			if spec.outputLitersPerHour > 0 and delta > 0 then
				local liters = foodFactor * math.min(spec.outputLitersPerHour, delta) * g_currentMission.environment.timeAdjustment

				if liters > 0 then
					self:addHusbandryFillLevelFromTool(self:getOwnerFarmId(), liters, spec.outputFillType, nil, ToolType.UNDEFINED, nil)
				end
			end

			self:updatePlane()
		end
	end

	superFunc(self, foodFactor, productionFactor, globalProductionFactor)
end

function PlaceableHusbandryBedding:getConditionInfos(superFunc)
	local infos = superFunc(self)
	local spec = self.spec_husbandryBedding
	local fillLevel = self:getHusbandryFillLevel(spec.inputFillType)

	if fillLevel > 0 then
		local extendFillType = g_fillTypeManager:getFillTypeByIndex(spec.extendFillType)
		local indexToUse = nil

		for i, info in ipairs(infos) do
			if info.title == extendFillType.title and info.value <= 0 then
				indexToUse = i

				break
			end
		end

		if indexToUse ~= nil then
			infos[indexToUse] = nil
			local fillType = g_fillTypeManager:getFillTypeByIndex(spec.inputFillType)
			local capacity = self:getHusbandryCapacity(spec.inputFillType)
			local ratio = 0

			if capacity > 0 then
				ratio = fillLevel / capacity
			end

			infos[indexToUse] = {
				invertedBar = false,
				title = fillType.title,
				value = fillLevel,
				ratio = ratio
			}
		end
	end

	return infos
end

function PlaceableHusbandryBedding:updateInfo(superFunc, infoTable)
	superFunc(self, infoTable)

	local spec = self.spec_husbandryBedding
	local fillLevel = self:getHusbandryFillLevel(spec.inputFillType)
	spec.info.text = string.format("%d l", fillLevel)

	table.insert(infoTable, spec.info)
end
