AutomaticDischarging = {
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(Dischargeable, specializations)
	end
}

function AutomaticDischarging.registerOverwrittenFunctions(vehicleType)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanToggleDischargeToGround", AutomaticDischarging.getCanToggleDischargeToGround)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "handleDischargeRaycast", AutomaticDischarging.handleDischargeRaycast)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanDischargeToGround", AutomaticDischarging.getCanDischargeToGround)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getIsDischargeNodeActive", AutomaticDischarging.getIsDischargeNodeActive)
	SpecializationUtil.registerOverwrittenFunction(vehicleType, "getCanDischargeToLand", AutomaticDischarging.getCanDischargeToLand)
end

function AutomaticDischarging.registerEventListeners(vehicleType)
end

function AutomaticDischarging:getCanToggleDischargeToGround()
	return false
end

function AutomaticDischarging:handleDischargeRaycast(superFunc, dischargeNode, ...)
	superFunc(self, dischargeNode, ...)

	if self:getCanDischargeToGround(dischargeNode) then
		self:setDischargeState(Dischargeable.DISCHARGE_STATE_GROUND)
	end
end

function AutomaticDischarging:getCanDischargeToGround(superFunc, ...)
	if not superFunc(self, ...) then
		return false
	end

	return self:getIsTurnedOn()
end

function AutomaticDischarging:getIsDischargeNodeActive(superFunc, ...)
	if not superFunc(self, ...) then
		return false
	end

	return self:getIsTurnedOn()
end

function AutomaticDischarging:getCanDischargeToLand(superFunc, dischargeNode)
	if dischargeNode == nil then
		return false
	end

	local info = dischargeNode.info
	local sx, sy, sz = localToWorld(info.node, -info.width, 0, info.zOffset)
	local ex, ey, ez = localToWorld(info.node, info.width, 0, info.zOffset)
	local activeFarm = self:getActiveFarm()

	if not g_currentMission.accessHandler:canFarmAccessLand(activeFarm, sx, sz) and not g_missionManager:getIsMissionWorkAllowed(activeFarm, sx, sz) then
		return false
	end

	if not g_currentMission.accessHandler:canFarmAccessLand(activeFarm, ex, ez) and not g_missionManager:getIsMissionWorkAllowed(activeFarm, ex, ez) then
		return false
	end

	return true
end
