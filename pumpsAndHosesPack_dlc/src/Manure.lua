Manure = class("Manure")

function Manure:construct(modName, modDirectory, mission, i3DManager, i18n)
	self.modName = modName
	self.modDirectory = modDirectory
	self.mission = mission
	self.i18n = i18n
	self.isServer = mission:getIsServer()
	self.isClient = mission:getIsClient()
	self.isDebug = false
	self.shapeCacheContainer = I3DShapeContainer(i3DManager, modDirectory)

	self.shapeCacheContainer:loadByXML("data/shared/hose/hoses.xml")

	self.hoses = {}

	if g_addCheatCommands then
		addConsoleCommand("pnhUmbilicalToggleDebug", "Toggle umbilical debug", "consoleCommandToggleDebug", self)
		addConsoleCommand("pnhUmbilicalAddReelHose", "Adds hose to the reel", "consoleCommandAddReelHose", self)
		addConsoleCommand("pnhUmbilicalAddDamageToHose", "Adds damage to all hoses", "consoleCommandAddHoseDamage", self)
	end
end

function Manure:delete()
	self.shapeCacheContainer:delete()
	removeConsoleCommand("pnhUmbilicalToggleDebug")
	removeConsoleCommand("pnhUmbilicalAddReelHose")
	removeConsoleCommand("pnhUmbilicalAddDamageToHose")
end

function Manure:createUmbilicalHose()
	return UmbilicalHoseOrchestrator.construct(self.mission, self.shapeCacheContainer, self.isServer, self.isClient)
end

function Manure:addUmbilicalHose(hose)
	table.addElement(self.hoses, hose)
end

function Manure:deleteUmbilicalHose(hose)
	if table.removeElement(self.hoses, hose) then
		hose:delete()
	end
end

function Manure:getClosestUmbilicalHose(node, minDistance, bufferTable, excludeHose, includeConnectedHoses)
	if node == nil then
		return bufferTable
	end

	minDistance = minDistance or 2
	includeConnectedHoses = includeConnectedHoses or false
	bufferTable.distance = math.huge
	local farmId = self.mission:getFarmId()

	for _, hose in ipairs(self.hoses) do
		if hose ~= excludeHose and hose.isFinalized and hose:getOwnerFarmId() == farmId then
			local hasNoConnectorInfo = not hose:hasConnectionOnBothEnds()

			if hose:hasControlPoints() and (hasNoConnectorInfo or includeConnectedHoses) then
				local hoseNode, distance, type = hose:getClosestDistanceToEnds(node, bufferTable.distance, minDistance)

				if hoseNode ~= nil and distance < minDistance and distance < bufferTable.distance then
					local info = hose:getConnectorInfoByType(type)
					local canBeFound = info == nil

					if includeConnectedHoses then
						canBeFound = canBeFound or info.isHose
					end

					if canBeFound then
						bufferTable.distance = distance
						bufferTable.node = node
						bufferTable.type = type
						bufferTable.hose = hose
					end
				end
			end
		end
	end

	return bufferTable
end

function Manure:showHoseContext(name, fromHandTool)
	fromHandTool = fromHandTool or false
	local input = fromHandTool and InputAction.ACTIVATE_HANDTOOL or InputAction.PM_ATTACH
	local actionText = self.i18n:getText("action_attach")

	self.mission.hud.contextActionDisplay:setContext(input, ContextActionDisplay.CONTEXT_ICON.ATTACH, name, HUD.CONTEXT_PRIORITY.LOW, actionText)
end

function Manure:showReelContext(name)
	local actionText = self.i18n:getText("action_reelOverloadInactive")

	self.mission.hud.contextActionDisplay:setContext(InputAction.PM_TOGGLE_REEL_OVERLOAD, ContextActionDisplay.CONTEXT_ICON.FUEL, name, HUD.CONTEXT_PRIORITY.MEDIUM, actionText)
end

function Manure.installPlaceableSpecializations(typeManager, specializationManager, modDirectory, modName)
	for typeName, typeEntry in pairs(typeManager:getTypes()) do
		if typeName == "silo" then
			typeManager:addSpecialization(typeName, modName .. ".sandboxPlaceable")
		end

		if SpecializationUtil.hasSpecialization(SandboxPlaceable, typeEntry.specializations) and not SpecializationUtil.hasSpecialization(SandboxPlaceableBunker, typeEntry.specializations) and SpecializationUtil.hasSpecialization(PlaceableSilo, typeEntry.specializations) then
			typeManager:addSpecialization(typeName, modName .. ".sandboxPlaceableSilo")
		end

		if SpecializationUtil.hasSpecialization(PlaceableHusbandryStraw, typeEntry.specializations) then
			typeManager:addSpecialization(typeName, modName .. ".husbandryBedding")
		end
	end
end

function Manure.installVehicleSpecializations(typeManager, specializationManager, modDirectory, modName)
	for typeName, typeEntry in pairs(typeManager:getTypes()) do
		if SpecializationUtil.hasSpecialization(Motorized, typeEntry.specializations) and SpecializationUtil.hasSpecialization(AttacherJoints, typeEntry.specializations) then
			typeManager:addSpecialization(typeName, modName .. ".umbilicalPumpMotor")
		end
	end
end

function Manure:consoleCommandToggleDebug()
	self.isDebug = not self.isDebug
end

function Manure:consoleCommandAddHoseDamage(damage)
	local usage = "Usage: 'pnhUmbilicalAddDamageToHose [damage]'"
	damage = tonumber(damage) or 0

	for _, hose in ipairs(self.hoses) do
		hose:setDamageAmount(hose.damage + damage, true)
	end

	return usage
end

function Manure:consoleCommandAddReelHose(length)
	local usage = "Usage: 'pnhUmbilicalAddReelHose [length]'"
	length = tonumber(length) or 0
	local controlledVehicle = self.mission.controlledVehicle

	if controlledVehicle ~= nil and controlledVehicle.getSelectedObject ~= nil then
		local vehicle = controlledVehicle:getSelectedVehicle()

		if vehicle ~= nil and vehicle:getIsActive() and vehicle.addReelHose ~= nil then
			local reel = vehicle:getInteractiveReel()

			if reel.isActive then
				return "Reel is active!"
			end

			if reel:getFreeCapacity() < length then
				return ("Not enough capacity left to add hose length %s"):format(length)
			end

			local color = {
				HoseBase.COLOR_DEFAULT_RED,
				HoseBase.COLOR_DEFAULT_GREEN,
				HoseBase.COLOR_DEFAULT_BLUE
			}

			vehicle:addReelHose(reel.id, length, color)

			return ("Added hose with length %s"):format(length)
		end
	end

	return usage
end
