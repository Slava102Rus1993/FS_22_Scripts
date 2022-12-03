ExtendedWeedControl = {
	MOD_NAME = g_currentModName,
	SPRAYER_NOZZLE_EFFECT_FILENAME = g_currentModDirectory .. "shared/sprayerNozzleEffect.i3d"
}
local ExtendedWeedControl_mt = Class(ExtendedWeedControl)

function ExtendedWeedControl.new(precisionFarming, customMt)
	local self = setmetatable({}, customMt or ExtendedWeedControl_mt)
	self.precisionFarming = precisionFarming
	self.lastUseSpotSpraying = false
	self.rangeMax1 = 10000
	self.rangeMin1 = 3000
	self.persistence1 = 0.5
	self.numOctave1 = 1
	self.minOctave1 = 8
	self.rangeMax2 = 10000
	self.rangeMin2 = 500
	self.persistence2 = 0.5
	self.numOctave2 = 1
	self.minOctave2 = 12

	addConsoleCommand("pfWeedSetNoiseParameters", "Sets current weed noise parameters", "setWeedNoiseParameters", self)

	return self
end

function ExtendedWeedControl:loadFromXML(_, _, baseDirectory, configFileName, mapFilename)
	g_i3DManager:loadI3DFileAsync(ExtendedWeedControl.SPRAYER_NOZZLE_EFFECT_FILENAME, true, true, ExtendedWeedControl.onSprayerEffectLoaded, self, {})
end

function ExtendedWeedControl:unloadMapData()
	if self.sprayerEffectNode ~= nil then
		delete(self.sprayerEffectNode)

		self.sprayerEffectNode = nil
	end

	self.perlinNoiseFilter1 = nil
	self.perlinNoiseFilter2 = nil
	self.filtersInitilized = false
	self.weedFilter = nil

	removeConsoleCommand("pfWeedSetNoiseParameters")
end

function ExtendedWeedControl:onSprayerEffectLoaded(i3dNode, failedReason, args)
	if i3dNode ~= 0 then
		self.sprayerEffectNode = getChildAt(i3dNode, 0)

		unlink(self.sprayerEffectNode)
		delete(i3dNode)
	end
end

function ExtendedWeedControl:getClonedSprayerEffectNode()
	if self.sprayerEffectNode ~= nil then
		return clone(self.sprayerEffectNode, false, false, false)
	end
end

function ExtendedWeedControl:updateDensityMapFilter()
	local weedSystem = g_currentMission.weedSystem
	local weedMapId, _, _ = weedSystem:getDensityMapData()

	if weedMapId ~= nil and not self.filtersInitilized then
		self.perlinNoiseFilter1 = PerlinNoiseFilter.new(weedMapId, self.minOctave1, self.numOctave1, self.persistence1, math.random(0, 1000))

		self.perlinNoiseFilter1:setValueCompareParams(DensityValueCompareType.BETWEEN, self.rangeMin1, self.rangeMax1)

		self.perlinNoiseFilter2 = PerlinNoiseFilter.new(weedMapId, self.minOctave2, self.numOctave2, self.persistence2, math.random(0, 1000))

		self.perlinNoiseFilter2:setValueCompareParams(DensityValueCompareType.BETWEEN, self.rangeMin2, self.rangeMax2)

		self.filtersInitilized = true
	end
end

function ExtendedWeedControl:setWeedNoiseParameters(minOctave1, numOctave1, persistence1, rangeMin1, rangeMax1, minOctave2, numOctave2, persistence2, rangeMin2, rangeMax2)
	rangeMax2 = tonumber(rangeMax2)
	rangeMin2 = tonumber(rangeMin2)
	persistence2 = tonumber(persistence2)
	numOctave2 = tonumber(numOctave2)
	minOctave2 = tonumber(minOctave2)
	rangeMax1 = tonumber(rangeMax1)
	rangeMin1 = tonumber(rangeMin1)
	persistence1 = tonumber(persistence1)
	numOctave1 = tonumber(numOctave1)
	minOctave1 = tonumber(minOctave1)
	self.rangeMax1 = rangeMax1 or self.rangeMax1
	self.rangeMin1 = rangeMin1 or self.rangeMin1
	self.persistence1 = persistence1 or self.persistence1
	self.numOctave1 = numOctave1 or self.numOctave1
	self.minOctave1 = minOctave1 or self.minOctave1
	self.rangeMax2 = rangeMax2 or self.rangeMax2
	self.rangeMin2 = rangeMin2 or self.rangeMin2
	self.persistence2 = persistence2 or self.persistence2
	self.numOctave2 = numOctave2 or self.numOctave2
	self.minOctave2 = minOctave2 or self.minOctave2

	log("Weed Noise Parameters:")
	log(string.format("  minOctave1 %.2f, numOctave1 %.2f, persistence1 %.2f, rangeMin1 %d, rangeMax1 %d", self.minOctave1, self.numOctave1, self.persistence1, self.rangeMin1, self.rangeMax1))
	log(string.format("  minOctave2 %.2f, numOctave2 %.2f, persistence2 %.2f, rangeMin2 %d, rangeMax2 %d", self.minOctave2, self.numOctave2, self.persistence2, self.rangeMin2, self.rangeMax2))

	self.filtersInitilized = false
end

function ExtendedWeedControl:clearWeedArea(modifier, weedFilter)
	modifier:executeSet(0, self.perlinNoiseFilter1, self.perlinNoiseFilter2, weedFilter)
end

function ExtendedWeedControl:overwriteGameFunctions(pfModule)
	pfModule:overwriteGameFunction(FSDensityMapUtil, "setSowingWeedArea", function (superFunc, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
		superFunc(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)

		local weedSystem = g_currentMission.weedSystem

		if weedSystem:getMapHasWeed() then
			local functionData = FSDensityMapUtil.functionCache.setSowingWeedArea

			if functionData ~= nil then
				self:updateDensityMapFilter()

				if self.filtersInitilized then
					if self.weedFilterDense == nil or self.weedFilterSparse == nil then
						local weedMapId, weedFirstChannel, weedNumChannels = weedSystem:getDensityMapData()
						self.weedFilterDense = DensityMapFilter.new(weedMapId, weedFirstChannel, weedNumChannels, g_currentMission.terrainRootNode)

						self.weedFilterDense:setValueCompareParams(DensityValueCompareType.EQUAL, functionData.denseState)

						self.weedFilterSparse = DensityMapFilter.new(weedMapId, weedFirstChannel, weedNumChannels, g_currentMission.terrainRootNode)

						self.weedFilterSparse:setValueCompareParams(DensityValueCompareType.EQUAL, functionData.sparseState)
					end

					local weedModifier = functionData.weedModifier

					weedModifier:setParallelogramWorldCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
					self:clearWeedArea(weedModifier, self.weedFilterDense)
					self:clearWeedArea(weedModifier, self.weedFilterSparse)
				end
			end
		end
	end)
	pfModule:overwriteGameFunction(FieldManager, "setFieldGround", function (superFunc, _self, field, ...)
		local ret = superFunc(_self, field, ...)

		if field == nil or field.fieldDimensions == nil then
			return false
		end

		self:updateDensityMapFilter()

		if self.filtersInitilized then
			local numDimensions = getNumOfChildren(field.fieldDimensions)

			for i = 1, numDimensions do
				local dimWidth = getChildAt(field.fieldDimensions, i - 1)
				local dimStart = getChildAt(dimWidth, 0)
				local dimHeight = getChildAt(dimWidth, 1)
				local x, _, z = getWorldTranslation(dimStart)
				local x1, _, z1 = getWorldTranslation(dimWidth)
				local x2, _, z2 = getWorldTranslation(dimHeight)

				if _self.weedModifier ~= nil then
					_self.weedModifier:setParallelogramWorldCoords(x, z, x1, z1, x2, z2, DensityCoordType.POINT_POINT_POINT)
					self:clearWeedArea(_self.weedModifier)
				end
			end
		end

		return ret
	end)
	pfModule:overwriteGameFunction(FieldManager, "consoleCommandSetFieldFruit", function (superFunc, fieldManager, ...)
		self.filtersInitilized = false

		return superFunc(fieldManager, ...)
	end)
	pfModule:overwriteGameFunction(AIImplement, "getAILookAheadSize", function (superFunc, vehicle)
		local size = superFunc(vehicle)

		if vehicle.spec_weeder ~= nil then
			return math.max(size, 6)
		end

		if vehicle.spec_sprayer ~= nil and vehicle.spec_sprayer.workAreaParameters.sprayFillType == FillType.HERBICIDE then
			return math.max(size, 4)
		end

		return size
	end)
	pfModule:overwriteGameFunction(Sprayer, "processSprayerArea", function (superFunc, vehicle, workArea, dt)
		self.lastUseSpotSpraying = vehicle.getIsSpotSprayEnabled ~= nil and vehicle:getIsSpotSprayEnabled()

		return superFunc(vehicle, workArea, dt)
	end)
	pfModule:overwriteGameFunction(FSDensityMapUtil, "updateHerbicideArea", function (superFunc, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, groundType)
		local numPixels, totalNumPixels = superFunc(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, groundType)
		local weedSystem = g_currentMission.weedSystem

		if weedSystem:getMapHasWeed() then
			local functionData = FSDensityMapUtil.functionCache.updateHerbicideArea

			if functionData ~= nil and functionData.weedFilters ~= nil then
				if self.lastUseSpotSpraying then
					functionData.weedFilters[1]:setValueCompareParams(DensityValueCompareType.EQUAL, 0)
					functionData.weedFilters[2]:setValueCompareParams(DensityValueCompareType.EQUAL, 0)
				else
					functionData.weedFilters[1]:setValueCompareParams(DensityValueCompareType.EQUAL, 1)
					functionData.weedFilters[2]:setValueCompareParams(DensityValueCompareType.EQUAL, 2)
				end
			end
		end

		return numPixels, totalNumPixels
	end)
end
