SuperCupVehicle = {
	MOD_NAME = g_currentModName,
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(Drivable, specializations)
	end
}

function SuperCupVehicle.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "setAllowDriveSuperCup", SuperCupVehicle.setAllowDriveSuperCup)
	SpecializationUtil.registerFunction(vehicleType, "getAllowDriveSuperCup", SuperCupVehicle.getAllowDriveSuperCup)
end

function SuperCupVehicle.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsVehicleControlledByPlayer", SuperCupVehicle.getIsVehicleControlledByPlayer)
end

function SuperCupVehicle.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", SuperCupVehicle)
	SpecializationUtil.registerEventListener(vehicleType, "onDelete", SuperCupVehicle)
end

function SuperCupVehicle:onLoad(savegame)
	self.spec_superCupVehicle = self[("spec_%s.superCupVehicle"):format(SuperCupVehicle.MOD_NAME)]
	local spec = self.spec_superCupVehicle
	spec.allowDriving = false
end

function SuperCupVehicle:onDelete()
end

function SuperCupVehicle:setAllowDriveSuperCup(allowDriving, object, noEventSend)
	local spec = self.spec_superCupVehicle
	spec.superCupObject = object

	if spec.allowDriving ~= allowDriving then
		SuperCupDriverEvent.sendEvent(self, allowDriving, object, noEventSend)

		spec.allowDriving = allowDriving
		local spec_enterable = self.spec_enterable

		if spec_enterable ~= nil then
			spec_enterable.exitPoint = object.spec_superCup.superCup.superCupExitReferenceNode
		end
	end
end

function SuperCupVehicle:getAllowDriveSuperCup()
	local spec = self.spec_superCupVehicle

	return spec.allowDriving
end

function SuperCupVehicle:getIsVehicleControlledByPlayer(superFunc)
	return superFunc(self) and self:getAllowDriveSuperCup()
end
