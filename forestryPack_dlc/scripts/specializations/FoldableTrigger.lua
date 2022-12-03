local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

FoldableTrigger = {
	MOD_NAME = g_currentModName,
	SPEC_NAME = g_currentModName .. ".foldableTrigger",
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(Foldable, specializations)
	end,
	initSpecialization = function ()
		local schema = Vehicle.xmlSchema

		schema:setXMLSpecializationType("FoldableTrigger")
		schema:register(XMLValueType.NODE_INDEX, "vehicle.foldableTrigger#triggerNode", "Player trigger node")
		schema:setXMLSpecializationType()
	end
}

function FoldableTrigger.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "onFoldableTriggerCallback", FoldableTrigger.onFoldableTriggerCallback)
end

function FoldableTrigger.registerOverwrittenFunctions(vehicleType)
end

function FoldableTrigger.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", FoldableTrigger)
	SpecializationUtil.registerEventListener(vehicleType, "onLoadFinished", FoldableTrigger)
	SpecializationUtil.registerEventListener(vehicleType, "onDelete", FoldableTrigger)
	SpecializationUtil.registerEventListener(vehicleType, "onFoldStateChanged", FoldableTrigger)
end

function FoldableTrigger:onLoad(savegame)
	self.spec_foldableTrigger = self["spec_" .. FoldableTrigger.SPEC_NAME]
	local spec = self.spec_foldableTrigger
	spec.triggerNode = self.xmlFile:getValue("vehicle.foldableTrigger#triggerNode", nil, self.components, self.i3dMappings)

	if spec.triggerNode ~= nil then
		addTrigger(spec.triggerNode, "onFoldableTriggerCallback", self)
	end

	spec.isPlayerInRange = false
end

function FoldableTrigger:onLoadFinished(savegame)
	local spec = self.spec_foldableTrigger
	spec.activatable = FoldableTriggerActivatable.new(self)
end

function FoldableTrigger:onDelete()
	local spec = self.spec_foldableTrigger

	if spec.triggerNode ~= nil then
		removeTrigger(spec.triggerNode)
	end

	g_currentMission.activatableObjectsSystem:removeActivatable(spec.activatable)
end

function FoldableTrigger:onFoldStateChanged(direction, moveToMiddle)
	local spec = self.spec_foldableTrigger

	spec.activatable:updateText()
end

function FoldableTrigger:onFoldableTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay)
	if g_currentMission.player ~= nil and otherId == g_currentMission.player.rootNode then
		local spec = self.spec_foldableTrigger

		if onEnter then
			spec.isPlayerInRange = true

			spec.activatable:updateText()
			g_currentMission.activatableObjectsSystem:addActivatable(spec.activatable)
		else
			spec.isPlayerInRange = false

			g_currentMission.activatableObjectsSystem:removeActivatable(spec.activatable)
		end
	end
end

FoldableTriggerActivatable = {}
local FoldableTriggerActivatable_mt = Class(FoldableTriggerActivatable)

function FoldableTriggerActivatable.new(vehicle)
	local self = setmetatable({}, FoldableTriggerActivatable_mt)
	self.vehicle = vehicle

	self:updateText()

	return self
end

function FoldableTriggerActivatable:getIsActivatable()
	if not g_currentMission.accessHandler:canPlayerAccess(self.vehicle) then
		return false
	end

	return self.vehicle.spec_foldableTrigger.isPlayerInRange
end

function FoldableTriggerActivatable:run()
	local spec = self.vehicle.spec_foldable
	local toggleDirection = self.vehicle:getToggledFoldDirection()
	local allowed, warning = self.vehicle:getIsFoldAllowed(toggleDirection, false)

	if allowed then
		if toggleDirection == spec.turnOnFoldDirection then
			self.vehicle:setFoldState(toggleDirection, true)
		else
			self.vehicle:setFoldState(toggleDirection, false)
		end
	elseif warning ~= nil then
		g_currentMission:showBlinkingWarning(warning, 2000)
	end
end

function FoldableTriggerActivatable:getDistance(x, y, z)
	if self.vehicle.spec_foldableTrigger.triggerNode ~= nil then
		local tx, ty, tz = getWorldTranslation(self.vehicle.spec_foldableTrigger.triggerNode)

		return MathUtil.vector3Length(x - tx, y - ty, z - tz)
	end

	return math.huge
end

function FoldableTriggerActivatable:updateText()
	local spec = self.vehicle.spec_foldable
	local direction = self.vehicle:getToggledFoldDirection()

	if direction == spec.turnOnFoldDirection then
		self.activateText = spec.negDirectionText
	else
		self.activateText = spec.posDirectionText
	end
end
