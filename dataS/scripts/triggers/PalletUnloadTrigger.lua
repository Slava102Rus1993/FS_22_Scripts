PalletUnloadTrigger = {}
local PalletUnloadTrigger_mt = Class(PalletUnloadTrigger, Object)

InitStaticObjectClass(PalletUnloadTrigger, "PalletUnloadTrigger", ObjectIds.OBJECT_PALLET_UNLOAD_TRIGGER)

function PalletUnloadTrigger.registerXMLPaths(schema, basePath)
	schema:register(XMLValueType.NODE_INDEX, basePath .. "#triggerNode", "Trigger node")
end

function PalletUnloadTrigger.new(isServer, isClient, customMt)
	local self = Object.new(isServer, isClient, customMt or PalletUnloadTrigger_mt)
	self.triggerNode = nil
	self.extraAttributes = {
		price = 1
	}

	return self
end

function PalletUnloadTrigger:load(components, xmlFile, xmlNode, target, i3dMappings, rootNode)
	local triggerNodeKey = xmlNode .. "#triggerNode"
	self.triggerNode = xmlFile:getValue(triggerNodeKey, nil, components, i3dMappings)

	if self.triggerNode ~= nil then
		local colMask = getCollisionMask(self.triggerNode)

		if bitAND(CollisionFlag.VEHICLE, colMask) == 0 then
			Logging.xmlWarning(xmlFile, "Invalid collision mask for pallet trigger '%s'. Bit 13 needs to be set!", triggerNodeKey)

			return false
		end

		addTrigger(self.triggerNode, "palletTriggerCallback", self)
	else
		return false
	end

	if target ~= nil then
		self:setTarget(target)
	end

	return true
end

function PalletUnloadTrigger:delete()
	if self.triggerNode ~= nil and self.triggerNode ~= 0 then
		removeTrigger(self.triggerNode)

		self.triggerNode = 0
	end

	PalletUnloadTrigger:superClass().delete(self)
end

function PalletUnloadTrigger:setTarget(object)
	assert(object.getIsFillTypeAllowed ~= nil)
	assert(object.getIsToolTypeAllowed ~= nil)
	assert(object.addFillUnitFillLevel ~= nil)

	self.target = object
end

function PalletUnloadTrigger:getTarget()
	return self.target
end

function PalletUnloadTrigger:palletTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	if otherId ~= 0 then
		local object = g_currentMission:getNodeObject(otherId)

		if object ~= nil and object:isa(Vehicle) and object.isPallet and object.getFillUnits ~= nil then
			local fillUnits = object:getFillUnits()

			for fillUnitIndex, _ in pairs(fillUnits) do
				local fillTypeIndex = object:getFillUnitFillType(fillUnitIndex)

				if fillTypeIndex ~= FillType.UNKNOWN and self.target:getIsFillTypeSupported(fillTypeIndex) and object:getFillUnitFillLevel(fillUnitIndex) > 0 then
					if object.getMountObject ~= nil and object:getMountObject() ~= nil then
						object:unmountDynamic()

						local mountObject = object:getMountObject()

						if mountObject.setAllTensionBeltsActive ~= nil then
							mountObject:setAllTensionBeltsActive(false)
						end
					end

					if object.getPalletUnloadTriggerExtraSellPrice ~= nil and self.target ~= nil and self.target.target ~= nil and self.target.target.moneyChangeType ~= nil then
						g_currentMission:addMoney(object:getPalletUnloadTriggerExtraSellPrice(), object:getOwnerFarmId(), self.target.target.moneyChangeType, true)
					end

					local fillLevelDelta = object:addFillUnitFillLevel(object:getOwnerFarmId(), fillUnitIndex, -math.huge, fillTypeIndex, ToolType.UNDEFINED)

					self.target:addFillUnitFillLevel(object:getOwnerFarmId(), fillUnitIndex, -fillLevelDelta, fillTypeIndex, ToolType.UNDEFINED)
				end
			end
		end
	end
end

function PalletUnloadTrigger:getNeedRaiseActive()
	return false
end
