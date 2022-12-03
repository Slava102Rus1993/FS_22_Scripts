UmbilicalPumpMotor = {
	MOD_DIRECTORY = g_currentModDirectory,
	MOD_NAME = g_currentModName,
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(Motorized, specializations) and SpecializationUtil.hasSpecialization(AttacherJoints, specializations)
	end
}

function UmbilicalPumpMotor.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "hasActiveUmbilicalPump", UmbilicalPumpMotor.hasActiveUmbilicalPump)
end

function UmbilicalPumpMotor.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", UmbilicalPumpMotor)
	SpecializationUtil.registerEventListener(vehicleType, "onPreAttachImplement", UmbilicalPumpMotor)
	SpecializationUtil.registerEventListener(vehicleType, "onPreDetachImplement", UmbilicalPumpMotor)
end

function UmbilicalPumpMotor.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getStopMotorOnLeave", UmbilicalPumpMotor.getStopMotorOnLeave)
end

function UmbilicalPumpMotor:onLoad(savegame)
	self.spec_umbilicalPumpMotor = self[("spec_%s.umbilicalPumpMotor"):format(UmbilicalPumpMotor.MOD_NAME)]
	local spec = self.spec_umbilicalPumpMotor
	spec.pumpObjects = {}
end

function UmbilicalPumpMotor:hasActiveUmbilicalPump()
	local spec = self.spec_umbilicalPumpMotor

	for object, _ in pairs(spec.pumpObjects) do
		if object ~= nil and object:isPumpActive() then
			return true
		end
	end

	return false
end

function UmbilicalPumpMotor:onPreAttachImplement(object)
	local spec = self.spec_umbilicalPumpMotor

	if object ~= nil and object.isPumpActive ~= nil then
		spec.pumpObjects[object] = true
	end
end

function UmbilicalPumpMotor:onPreDetachImplement(implement)
	local spec = self.spec_umbilicalPumpMotor
	spec.pumpObjects[implement.object] = nil
end

function UmbilicalPumpMotor:getStopMotorOnLeave(superFunc)
	return superFunc(self) and not self:hasActiveUmbilicalPump()
end
