local PF_MOD_NAME = "FS22_precisionFarming"

local function inject_extendedSprayerHUDExtension_getFillTypeSourceVehicle(self, superFunc, sprayer)
	if not SpecializationUtil.hasSpecialization(BufferedSprayer, sprayer.specializations) then
		return superFunc(self, sprayer)
	end

	local spec = sprayer.spec_sprayer

	for _, supportedSprayType in ipairs(spec.supportedSprayTypes) do
		for _, src in ipairs(spec.fillTypeSources[supportedSprayType]) do
			local vehicle = src.vehicle

			if SpecializationUtil.hasSpecialization(ToolCarrier, vehicle.specializations) then
				return vehicle, src.fillUnitIndex
			end
		end
	end

	return sprayer, sprayer:getSprayerFillUnitIndex()
end

local function inject_nitrogenMap_loadFromXML(self, superFunc, ...)
	if not superFunc(self, ...) then
		return false
	end

	local fillTypeIndex = FillType.SEPARATED_MANURE
	local nAmount = {
		amount = 0.002,
		fillTypeIndex = fillTypeIndex
	}

	table.insert(self.fertilizerUsage.nAmounts, nAmount)

	local applicationRate = {
		regularRate = 60,
		autoAdjustToFruit = false,
		fillTypeIndex = fillTypeIndex,
		ratesBySoilType = {}
	}

	table.insert(applicationRate.ratesBySoilType, {
		soilTypeIndex = 1,
		rate = 40 / self.amountPerState
	})
	table.insert(applicationRate.ratesBySoilType, {
		soilTypeIndex = 2,
		rate = 60 / self.amountPerState
	})
	table.insert(applicationRate.ratesBySoilType, {
		soilTypeIndex = 3,
		rate = 80 / self.amountPerState
	})
	table.insert(applicationRate.ratesBySoilType, {
		soilTypeIndex = 4,
		rate = 60 / self.amountPerState
	})
	table.insert(self.applicationRates, applicationRate)

	return true
end

function pnh_overwrite_pf()
	if not g_modIsLoaded[PF_MOD_NAME] then
		return
	end

	local precisionFarming = getfenv(0)[PF_MOD_NAME]

	if precisionFarming ~= nil then
		pnh_overwrite.overwrittenFunction(precisionFarming.ExtendedSprayerHUDExtension, "getFillTypeSourceVehicle", inject_extendedSprayerHUDExtension_getFillTypeSourceVehicle)
		pnh_overwrite.overwrittenFunction(precisionFarming.NitrogenMap, "loadFromXML", inject_nitrogenMap_loadFromXML)
	end
end

function pnh_overwrite_pf_typeManager(typeManager, specializationManager, modDirectory, modName)
	if not g_modIsLoaded[PF_MOD_NAME] then
		return
	end

	if not typeManager.isForVehicles then
		return
	end

	g_specializationManager:addSpecialization("pfExtendedSprayer", "PFExtendedSprayer", modDirectory .. "src/overwrites/thirdParty/PFExtendedSprayer.lua", modName)

	for typeName, typeEntry in pairs(typeManager:getTypes()) do
		if SpecializationUtil.hasSpecialization(Sprayer, typeEntry.specializations) then
			typeManager:addSpecialization(typeName, modName .. ".pfExtendedSprayer")
		end
	end
end
