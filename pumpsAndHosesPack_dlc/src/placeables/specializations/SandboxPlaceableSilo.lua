SandboxPlaceableSilo = {
	MOD_DIRECTORY = g_currentModDirectory,
	MOD_NAME = g_currentModName,
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(SandboxPlaceable, specializations) and SpecializationUtil.hasSpecialization(PlaceableSilo, specializations)
	end,
	registerEventListeners = function (placeableType)
		SpecializationUtil.registerEventListener(placeableType, "onLoad", SandboxPlaceableSilo)
	end
}

function SandboxPlaceableSilo:onLoad(savegame)
	self.spec_sandboxPlaceableSilo = self[("spec_%s.sandboxPlaceableSilo"):format(SandboxPlaceableSilo.MOD_NAME)]
	local spec = self.spec_sandboxPlaceableSilo
	local spec_silo = self.spec_silo

	if spec_silo ~= nil then
		for _, storage in ipairs(spec_silo.storages) do
			local added = false

			if storage.fillTypes[FillType.LIQUIDMANURE] and not storage.fillTypes[FillType.DIGESTATE] then
				storage.fillTypes[FillType.DIGESTATE] = true
				added = true
			end

			if added then
				table.clear(storage.sortedFillTypes)

				for fillType, _ in pairs(storage.fillTypes) do
					table.insert(storage.sortedFillTypes, fillType)

					storage.fillLevels[fillType] = 0
					storage.fillLevelsLastSynced[fillType] = 0
				end

				table.sort(storage.sortedFillTypes)

				if storage.fillPlanes[FillType.DIGESTATE] == nil and storage.fillPlanes[FillType.LIQUIDMANURE] ~= nil then
					local liquidManureFillPlane = storage.fillPlanes[FillType.LIQUIDMANURE]
					local fillPlane = FillPlane.new()
					fillPlane.node = clone(liquidManureFillPlane.node, true, false, true)
					fillPlane.moveMinY = liquidManureFillPlane.moveMinY
					fillPlane.moveMaxY = liquidManureFillPlane.moveMaxY
					fillPlane.colorChange = liquidManureFillPlane.colorChange
					fillPlane.rotMinX = liquidManureFillPlane.rotMinX
					fillPlane.rotMaxX = liquidManureFillPlane.rotMaxX
					fillPlane.changeVisibility = liquidManureFillPlane.changeVisibility
					fillPlane.loaded = true
					storage.fillPlanes[FillType.DIGESTATE] = fillPlane
				end
			end
		end

		if spec_silo.loadingStation ~= nil then
			for _, loadTrigger in ipairs(spec_silo.loadingStation.loadTriggers) do
				if loadTrigger:getIsFillTypeSupported(FillType.LIQUIDMANURE) and not loadTrigger:getIsFillTypeSupported(FillType.DIGESTATE) then
					loadTrigger.fillTypes[FillType.DIGESTATE] = true
				end
			end

			spec_silo.loadingStation:updateSupportedFillTypes()
		end
	end
end
