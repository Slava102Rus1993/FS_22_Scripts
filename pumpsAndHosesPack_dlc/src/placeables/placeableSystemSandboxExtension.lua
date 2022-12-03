function PlaceableSystem.addSandboxPlaceable(placeableSystem, placeable)
	if placeableSystem.sandboxPlaceables == nil then
		placeableSystem.sandboxPlaceables = {}
	end

	if placeable.isSandboxPlaceable ~= nil and placeable:isSandboxPlaceable() then
		table.addElement(placeableSystem.sandboxPlaceables, placeable)
	end

	if placeableSystem.specificSandboxRootNameUsed == nil then
		placeableSystem.specificSandboxRootNameUsed = {}
	end
end

function PlaceableSystem.removeSandboxPlaceable(placeableSystem, placeable)
	table.removeElement(placeableSystem.sandboxPlaceables, placeable)
end

function PlaceableSystem.getSandboxPlaceables(placeableSystem, farmId)
	if farmId ~= nil and placeableSystem.sandboxPlaceables ~= nil then
		local sandboxPlaceables = {}

		for _, placeable in pairs(placeableSystem.sandboxPlaceables) do
			if placeable:getOwnerFarmId() == farmId then
				table.addElement(sandboxPlaceables, placeable)
			end
		end

		return sandboxPlaceables
	else
		return placeableSystem.sandboxPlaceables
	end
end

function PlaceableSystem.getNextFreeRootNameIndex(placeableSystem, rootName, placeable)
	if placeableSystem.rootNameIndex == nil then
		placeableSystem.rootNameIndex = {}
	end

	if placeableSystem.rootNameIndex[rootName] == nil then
		placeableSystem.rootNameIndex[rootName] = {}
	end

	for index, placeableI in pairs(placeableSystem.rootNameIndex[rootName]) do
		if placeableI == nil or placeableI == placeable then
			return index
		end
	end

	table.addElement(placeableSystem.rootNameIndex[rootName], placeable)

	return #placeableSystem.rootNameIndex[rootName]
end

function PlaceableSystem.releaseRootNameIndex(placeableSystem, rootName, placeable)
	if placeableSystem.rootNameIndex ~= nil and placeableSystem.rootNameIndex[rootName] ~= nil then
		local index = nil

		for i, placeableI in pairs(placeableSystem.rootNameIndex[rootName]) do
			if placeableI == placeable then
				index = i

				break
			end
		end

		if index ~= nil then
			placeableSystem.rootNameIndex[rootName][index] = nil
		end
	end
end

function PlaceableSystem.finalizeSandboxRoots(placeableSystem)
	if placeableSystem.sandboxPlaceables == nil then
		placeableSystem.sandboxPlaceables = {}
	end

	for _, placeable in pairs(placeableSystem.sandboxPlaceables) do
		if placeable:isSandboxRoot() then
			placeable:finalizeSandboxRoot()
		end
	end
end
