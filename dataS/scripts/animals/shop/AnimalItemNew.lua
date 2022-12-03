AnimalItemNew = {}
local AnimalItemNew_mt = Class(AnimalItemNew)

function AnimalItemNew.new(subTypeIndex, age)
	local self = setmetatable({}, AnimalItemNew_mt)
	self.subTypeIndex = subTypeIndex
	self.age = age
	self.visual = g_currentMission.animalSystem:getVisualByAge(subTypeIndex, age)
	local subType = g_currentMission.animalSystem:getSubTypeByIndex(subTypeIndex)
	self.infos = {
		{
			title = g_i18n:getText("ui_age"),
			value = g_i18n:formatNumMonth(self.visual.minAge)
		}
	}

	if subType.supportsReproduction then
		table.insert(self.infos, {
			title = g_i18n:getText("infohud_reproductionDuration"),
			value = g_i18n:formatNumMonth(subType.reproductionDurationMonth)
		})
		table.insert(self.infos, {
			title = g_i18n:getText("infohud_reproductionMinAge"),
			value = g_i18n:formatNumMonth(subType.reproductionMinAgeMonth)
		})
	end

	return self
end

function AnimalItemNew:getName()
	return self.visual.store.name
end

function AnimalItemNew:getPrice()
	return g_currentMission.animalSystem:getAnimalBuyPrice(self.subTypeIndex, self.age)
end

function AnimalItemNew:getTranportationFee(numItems)
	return g_currentMission.animalSystem:getAnimalTransportFee(self.subTypeIndex, self.age) * numItems
end

function AnimalItemNew:getSubTypeIndex()
	return self.subTypeIndex
end

function AnimalItemNew:getAge()
	return self.age
end

function AnimalItemNew:getDescription()
	return self.visual.store.description
end

function AnimalItemNew:getFilename()
	return self.visual.store.imageFilename
end

function AnimalItemNew:getInfos()
	return self.infos
end
