--
-- SeedTreater
--
-- @author Stefan Maurus
-- @date   16/03/2022
--
-- Copyright (C) GIANTS Software GmbH, Confidential, All Rights Reserved.

---Specialization for seat treatment tools
-- @category Specializations
SeedTreater = {}

SeedTreater.MOD_NAME = g_currentModName
SeedTreater.SPEC_NAME = g_currentModName .. ".seedTreater"

---Checks if all prerequisite specializations are loaded
-- @param table specializations specializations
-- @return boolean hasPrerequisite true if all prerequisite specializations are loaded
-- @includeCode
function SeedTreater.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Dischargeable, specializations) and SpecializationUtil.hasSpecialization(FillUnit, specializations)
end

---
-- @includeCode
function SeedTreater.initSpecialization()
    local schema = Vehicle.xmlSchema
    schema:setXMLSpecializationType("SeedTreater")

    schema:register(XMLValueType.INT, "vehicle.seedTreater#fillUnitIndex", "Fill unit index with seed treatment liquid", 1)
    schema:register(XMLValueType.INT, "vehicle.seedTreater#dischargeNodeIndex", "Discharge node index", 1)
    schema:register(XMLValueType.FLOAT, "vehicle.seedTreater#usagePerLiter", "Usage of treatment liquid", 0.1)
    schema:register(XMLValueType.FLOAT, "vehicle.seedTreater#fillFromTriggerThreshold", "After this amount is available as free capacity the filling from nearby pallets starts", 5)
    schema:register(XMLValueType.FLOAT, "vehicle.seedTreater#treatmentSpeedFactor", "Speed factor while treatment is active", 0.1)

    schema:setXMLSpecializationType()
end

---
-- @includeCode
function SeedTreater.registerFunctions(vehicleType)
end

---
-- @includeCode
function SeedTreater.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "discharge", SeedTreater.discharge)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getDischargeFillType", SeedTreater.getDischargeFillType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "getDischargeNodeEmptyFactor", SeedTreater.getDischargeNodeEmptyFactor)
end

---
-- @includeCode
function SeedTreater.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", SeedTreater)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", SeedTreater)
end

---
-- @includeCode
function SeedTreater:onLoad(savegame)
    self.spec_seedTreater = self["spec_" .. SeedTreater.SPEC_NAME]
    local spec = self.spec_seedTreater

    spec.fillUnitIndex = self.xmlFile:getValue("vehicle.seedTreater#fillUnitIndex", 1)
    spec.dischargeNodeIndex = self.xmlFile:getValue("vehicle.seedTreater#dischargeNodeIndex", 1)
    spec.usagePerLiter = self.xmlFile:getValue("vehicle.seedTreater#usagePerLiter", 0.1)
    spec.fillFromTriggerThreshold = self.xmlFile:getValue("vehicle.seedTreater#fillFromTriggerThreshold", 5)
    spec.treatmentSpeedFactor = self.xmlFile:getValue("vehicle.seedTreater#treatmentSpeedFactor", 0.1)
end

---
-- @includeCode
function SeedTreater:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    if self.isServer then
        local spec = self.spec_seedTreater
        local fillUnit = self:getFillUnitByIndex(spec.fillUnitIndex)
        if fillUnit ~= nil then
            if (fillUnit.capacity-fillUnit.fillLevel) > 5 then
                local specFillUnit = self.spec_fillUnit
                if not specFillUnit.fillTrigger.isFilling then
                    for _, trigger in ipairs(specFillUnit.fillTrigger.triggers) do
                        if trigger:getCurrentFillType() == FillType.LIQUIDSEEDTREATMENT then
                            if trigger:getIsActivatable(self) then
                                self:setFillUnitIsFilling(true)
                            end
                        end
                    end
                end
            elseif self.spec_fillUnit.fillTrigger.isFilling and self:getDischargeState() ~= Dischargeable.DISCHARGE_STATE_OFF and (fillUnit.capacity-fillUnit.fillLevel) < 0.1 then
                self:setFillUnitIsFilling(false)
            end
        end
    end
end

---
-- @includeCode
function SeedTreater:discharge(superFunc, dischargeNode, emptyLiters)
    local dischargedLiters, minDropReached, hasMinDropFillLevel = superFunc(self, dischargeNode, emptyLiters)

    local spec = self.spec_seedTreater
    if dischargeNode.index == spec.dischargeNodeIndex then
        local fillType = self:getFillUnitFillType(dischargeNode.fillUnitIndex)
        if dischargeNode.fillTypeConverter ~= nil then
            local conversion = dischargeNode.fillTypeConverter[fillType]
            if conversion ~= nil then
                local usage = -dischargedLiters * spec.usagePerLiter
                if usage > 0 then
                    self:addFillUnitFillLevel(self:getOwnerFarmId(), spec.fillUnitIndex, -usage, self:getFillUnitFillType(spec.fillUnitIndex), ToolType.UNDEFINED, nil)
                end
            end
        end
    end

    return dischargedLiters, minDropReached, hasMinDropFillLevel
end

---
-- @includeCode
function SeedTreater:getDischargeFillType(superFunc, dischargeNode)
    local spec = self.spec_seedTreater
    if spec ~= nil and self:getFillUnitFillLevel(spec.fillUnitIndex) == 0 then
        return self:getFillUnitFillType(dischargeNode.fillUnitIndex), 1
    end

    return superFunc(self, dischargeNode)
end

---
-- @includeCode
function SeedTreater:getDischargeNodeEmptyFactor(superFunc, dischargeNode)
    local spec = self.spec_seedTreater

    local fillType = self:getFillUnitFillType(dischargeNode.fillUnitIndex)
    if dischargeNode.fillTypeConverter ~= nil then
        local conversion = dischargeNode.fillTypeConverter[fillType]
        if conversion == nil then
            return superFunc(self, dischargeNode)
        end
    end

    if self:getFillUnitFillLevel(spec.fillUnitIndex) == 0 then
        return superFunc(self, dischargeNode)
    end

    return superFunc(self, dischargeNode) * spec.treatmentSpeedFactor
end
