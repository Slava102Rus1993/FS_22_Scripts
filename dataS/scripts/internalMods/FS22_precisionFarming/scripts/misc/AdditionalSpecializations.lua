local modName = g_currentModName
local additionals = {}
local additionalsSpec = {
	sprayer = {
		modName .. ".extendedSprayer",
		modName .. ".manureSensor",
		modName .. ".weedSpotSpray"
	},
	sowingMachine = {
		modName .. ".extendedSowingMachine"
	},
	motorized = {
		modName .. ".extendedMotorized",
		modName .. ".cropSensor"
	},
	wearable = {
		modName .. ".extendedWearable"
	},
	aiFieldWorker = {
		modName .. ".extendedAIVehicle"
	},
	combine = {
		modName .. ".extendedCombine"
	},
	mower = {
		modName .. ".extendedMower"
	}
}
local globalSpec = {
	modName .. ".precisionFarmingStatistic"
}
local oldFinalizeTypes = TypeManager.finalizeTypes

function TypeManager:finalizeTypes(...)
	if self.typeName == "vehicle" and g_modIsLoaded[modName] then
		for typeName, typeEntry in pairs(self:getTypes()) do
			for _, spec in pairs(globalSpec) do
				if typeEntry.specializationsByName[spec] == nil then
					self:addSpecialization(typeName, spec)
				end
			end

			for name, _ in pairs(typeEntry.specializationsByName) do
				for addName, specs in pairs(additionalsSpec) do
					if name == addName then
						for i = 1, #specs do
							if typeEntry.specializationsByName[specs[i]] == nil then
								self:addSpecialization(typeName, specs[i])
							end
						end
					end
				end
			end

			for name, specs in pairs(additionals) do
				if typeName == name then
					for i = 1, #specs do
						if typeEntry.specializationsByName[specs[i]] == nil then
							self:addSpecialization(typeName, specs[i])
						end
					end
				end
			end
		end
	end

	oldFinalizeTypes(self, ...)
end
