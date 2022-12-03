PFExtendedSprayer = {
	MOD_DIRECTORY = g_currentModDirectory,
	MOD_NAME = g_currentModName,
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(ExtendedSprayer, specializations)
	end
}

function PFExtendedSprayer.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCurrentSprayerMode", PFExtendedSprayer.getCurrentSprayerMode)
end

function PFExtendedSprayer:getCurrentSprayerMode(superFunc)
	local isLiming, isFertilizing = superFunc(self)

	if isLiming or isFertilizing then
		return isLiming, isFertilizing
	end

	local sprayer, fillUnitIndex = FS22_precisionFarming.ExtendedSprayer.getFillTypeSourceVehicle(self)
	local fillType = sprayer:getFillUnitLastValidFillType(fillUnitIndex)

	if fillType == FillType.SEPARATED_MANURE then
		return false, true
	end

	return false, false
end
