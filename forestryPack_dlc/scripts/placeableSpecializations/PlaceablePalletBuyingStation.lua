local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

PlaceablePalletBuyingStation = {
	MOD_NAME = g_currentModName,
	SPEC_NAME = g_currentModName .. ".palletBuyingStation"
}
PlaceablePalletBuyingStation.SPEC = "spec_" .. PlaceablePalletBuyingStation.SPEC_NAME

function PlaceablePalletBuyingStation.prerequisitesPresent(specializations)
	return true
end

function PlaceablePalletBuyingStation.registerEventListeners(placeableType)
	SpecializationUtil.registerEventListener(placeableType, "onLoad", PlaceablePalletBuyingStation)
	SpecializationUtil.registerEventListener(placeableType, "onDelete", PlaceablePalletBuyingStation)
end

function PlaceablePalletBuyingStation.registerFunctions(placeableType)
	SpecializationUtil.registerFunction(placeableType, "openShop", PlaceablePalletBuyingStation.openShop)
	SpecializationUtil.registerFunction(placeableType, "onActivationTriggerCallback", PlaceablePalletBuyingStation.onActivationTriggerCallback)
	SpecializationUtil.registerFunction(placeableType, "shopCallback", PlaceablePalletBuyingStation.shopCallback)
	SpecializationUtil.registerFunction(placeableType, "tryToSpawnPallets", PlaceablePalletBuyingStation.tryToSpawnPallets)
	SpecializationUtil.registerFunction(placeableType, "onPalletBought", PlaceablePalletBuyingStation.onPalletBought)
end

function PlaceablePalletBuyingStation.registerXMLPaths(schema, basePath)
	schema:setXMLSpecializationType("PlaceablePalletBuyingStation")
	schema:register(XMLValueType.NODE_INDEX, basePath .. ".palletBuyingStation#triggerNode", "trigger node")
	schema:register(XMLValueType.STRING, basePath .. ".palletBuyingStation#triggerText", "trigger text")
	schema:register(XMLValueType.STRING, basePath .. ".palletBuyingStation.fillType(?)#name", "Fill type name")
	schema:register(XMLValueType.FLOAT, basePath .. ".palletBuyingStation.fillType(?)#priceScale", "Price scale", 1)
	PalletSpawner.registerXMLPaths(schema, basePath .. ".palletBuyingStation.palletSpawner")
	schema:setXMLSpecializationType()
end

function PlaceablePalletBuyingStation:onLoad(savegame)
	local spec = self[PlaceablePalletBuyingStation.SPEC]
	local key = "placeable.palletBuyingStation"
	spec.triggerNode = self.xmlFile:getValue(key .. "#triggerNode", nil, self.components, self.i3dMappings)

	if spec.triggerNode == nil then
		Logging.xmlError(self.xmlFile, "Missing triggerNode for pallet buying station %s", key)

		return
	end

	addTrigger(spec.triggerNode, "onActivationTriggerCallback", self)

	local palletSpawnerKey = key .. ".palletSpawner"

	if self.xmlFile:hasProperty(palletSpawnerKey) then
		spec.palletSpawner = PalletSpawner.new(self.baseDirectory)

		if not spec.palletSpawner:load(self.components, self.xmlFile, key .. ".palletSpawner", self.customEnvironment, self.i3dMappings) then
			Logging.xmlError(self.xmlFile, "Unable to load pallet spawner %s", palletSpawnerKey)

			return
		end
	end

	spec.pallets = {}
	local i = 0

	while true do
		local fillTypeKey = string.format(key .. ".fillType(%d)", i)

		if not self.xmlFile:hasProperty(fillTypeKey) then
			break
		end

		local fillTypeStr = self.xmlFile:getValue(fillTypeKey .. "#name")
		local fillType = g_fillTypeManager:getFillTypeByName(fillTypeStr)

		if fillType ~= nil then
			local fillTypeIndex = fillType.index
			local palletFilename = fillType.palletFilename
			local storeItem = g_storeManager:getItemByXMLFilename(palletFilename)
			local priceScale = self.xmlFile:getValue(fillTypeKey .. "#priceScale", 1)
			local pallet = {
				imageFilename = storeItem.imageFilename,
				title = fillType.title,
				price = MathUtil.round(storeItem.price * priceScale * EconomyManager.getPriceMultiplier(), 0),
				fillTypeIndex = fillTypeIndex
			}

			table.insert(spec.pallets, pallet)
		end

		i = i + 1
	end

	local text = g_i18n:getText(self.xmlFile:getValue(key .. "#triggerText", "palletShop_open"), self.customEnvironment)
	spec.activatable = PalletBuyingStationActivatable.new(self, text)

	return true
end

function PlaceablePalletBuyingStation:onDelete()
	local spec = self[PlaceablePalletBuyingStation.SPEC]

	if spec.palletSpawner ~= nil then
		spec.palletSpawner:delete()
	end

	if spec.triggerNode ~= nil then
		removeTrigger(spec.triggerNode)
	end
end

function PlaceablePalletBuyingStation:onActivationTriggerCallback(triggerId, otherId, onEnter, onLeave, onStay, otherShapeId)
	local spec = self[PlaceablePalletBuyingStation.SPEC]

	if (onEnter or onLeave) and g_currentMission.player and g_currentMission.player.rootNode == otherId then
		if onEnter then
			if Platform.isMobile and spec.activatable:getIsActivatable() then
				spec.activatable:run()

				return
			end

			g_currentMission.activatableObjectsSystem:addActivatable(spec.activatable)
		elseif onLeave then
			g_currentMission.activatableObjectsSystem:removeActivatable(spec.activatable)
		end
	end
end

function PlaceablePalletBuyingStation:openShop()
	if g_currentMission:getHasPlayerPermission(Farm.PERMISSION.BUY_VEHICLE) then
		local spec = self[PlaceablePalletBuyingStation.SPEC]

		PalletShop.show(self.shopCallback, self, spec.pallets, 10)
	else
		g_gui:showInfoDialog({
			text = g_i18n:getText("shop_messageNoPermissionGeneral")
		})
	end
end

function PlaceablePalletBuyingStation:shopCallback(selectedIndex, quantity)
	if selectedIndex == nil or quantity == nil then
		return
	end

	local spec = self[PlaceablePalletBuyingStation.SPEC]
	local pallet = spec.pallets[selectedIndex]

	if pallet == nil then
		return
	end

	local totalPrice = pallet.price * quantity
	local enoughMoney = true

	if totalPrice > 0 then
		enoughMoney = totalPrice <= g_currentMission:getMoney()
	end

	if not enoughMoney then
		g_gui:showInfoDialog({
			text = g_i18n:getText("shop_messageNotEnoughMoneyToBuy", self.customEnvironment)
		})

		return
	end

	local enoughSlots = g_currentMission.slotSystem:getCanAddLimitedObjects(SlotSystem.LIMITED_OBJECT_PALLET, quantity)

	if not enoughSlots then
		g_gui:showInfoDialog({
			text = g_i18n:getText("shop_messageNotEnoughSlotsToBuy", self.customEnvironment)
		})

		return
	end

	local text = string.format(g_i18n:getText("shop_doYouWantToBuyPallet", self.customEnvironment), g_i18n:formatMoney(totalPrice, 0, true, true))

	local function callback(yes)
		if yes then
			g_gui:showMessageDialog({
				visible = true,
				text = g_i18n:getText("shop_buyingPallets", self.customEnvironment)
			})
			g_client:getServerConnection():sendEvent(PalletBuyEvent.new(self, g_currentMission.player.farmId, pallet.fillTypeIndex, quantity, pallet.price))
			g_messageCenter:subscribeOneshot(PalletBuyEvent, PlaceablePalletBuyingStation.onPalletBought, self)
		end
	end

	g_gui:showYesNoDialog({
		text = text,
		callback = callback
	})
end

function PlaceablePalletBuyingStation:tryToSpawnPallets(farmId, fillTypeIndex, quantity, callback)
	local spec = self[PlaceablePalletBuyingStation.SPEC]
	local numBoughtPallets = 0

	if spec.palletSpawner ~= nil then
		local function onPalletsSpawned(target, pallet, status, fillType)
			if pallet ~= nil then
				numBoughtPallets = numBoughtPallets + 1
				local fillUnitIndex = pallet:getFirstValidFillUnitToFill(fillType)

				if fillUnitIndex then
					pallet:addFillUnitFillLevel(farmId, fillUnitIndex, math.huge, fillType, ToolType.UNDEFINED)
				end

				if numBoughtPallets < quantity then
					spec.palletSpawner:spawnPallet(farmId, fillTypeIndex, onPalletsSpawned, nil)
				else
					callback(status, numBoughtPallets)
				end
			else
				callback(status, numBoughtPallets)
			end
		end

		spec.palletSpawner:spawnPallet(farmId, fillTypeIndex, onPalletsSpawned, nil)
	end
end

function PlaceablePalletBuyingStation:onPalletBought(errorCode, numBoughtPallets)
	g_gui:showMessageDialog({
		visible = false
	})

	if errorCode == PalletSpawner.RESULT_SUCCESS then
		g_gui:showInfoDialog({
			text = g_i18n:getText("shop_messageAllPalletsBought", self.customEnvironment)
		})

		return
	end

	local text = g_i18n:getText("shop_messagePalletsCouldNotBeLoaded", self.customEnvironment)

	if errorCode == PalletSpawner.RESULT_NO_SPACE then
		text = g_i18n:getText("shop_messageNotEnoughSpaceToBuyAllPallets", self.customEnvironment)
	elseif errorCode == PalletSpawner.PALLET_LIMITED_REACHED then
		text = g_i18n:getText("shop_messageNotEnoughSlotsToBuyAllPallets", self.customEnvironment)
	end

	if numBoughtPallets > 0 then
		text = text .. "\n" .. string.format(g_i18n:getText("shop_buyingPalletsAmount", self.customEnvironment), numBoughtPallets)
	end

	g_gui:showInfoDialog({
		text = text,
		dialogType = DialogElement.TYPE_WARNING
	})
end

PalletBuyingStationActivatable = {}
local PalletBuyingStationActivatable_mt = Class(PalletBuyingStationActivatable)

function PalletBuyingStationActivatable.new(placeable, text)
	local self = setmetatable({}, PalletBuyingStationActivatable_mt)
	self.placeable = placeable
	self.activateText = text

	return self
end

function PalletBuyingStationActivatable:getIsActivatable()
	return g_currentMission.accessHandler:canPlayerAccess(self.placeable)
end

function PalletBuyingStationActivatable:run()
	self.placeable:openShop()
end
