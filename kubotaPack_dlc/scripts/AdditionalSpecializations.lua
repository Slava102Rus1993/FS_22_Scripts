local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_kubotaPack" then
	return
end

local modName = g_currentModName
local additionals = {}
local additionalsSpec = {
	enterable = {
		modName .. ".enterablePassenger"
	}
}
local globalSpec = {}
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
