SellPlaceableEvent = {
	STATE_SUCCESS = 0,
	STATE_FAILED = 1,
	STATE_NO_PERMISSION = 2,
	STATE_IN_USE = 3
}
local SellPlaceableEvent_mt = Class(SellPlaceableEvent, Event)

InitStaticEventClass(SellPlaceableEvent, "SellPlaceableEvent", EventIds.EVENT_SELL_PLACEABLE)

function SellPlaceableEvent.emptyNew()
	local self = Event.new(SellPlaceableEvent_mt)

	return self
end

function SellPlaceableEvent.new(placeable, forFree, forFullPrice)
	local self = SellPlaceableEvent.emptyNew()
	self.placeable = placeable
	self.forFree = Utils.getNoNil(forFree, false)
	self.forFullPrice = Utils.getNoNil(forFullPrice, false)

	return self
end

function SellPlaceableEvent.newServerToClient(state, sellPrice)
	local self = SellPlaceableEvent.emptyNew()
	self.state = state
	self.sellPrice = sellPrice

	return self
end

function SellPlaceableEvent:readStream(streamId, connection)
	if not connection:getIsServer() then
		self.placeable = NetworkUtil.readNodeObject(streamId)
		self.forFree = streamReadBool(streamId)
		self.forFullPrice = streamReadBool(streamId)
	else
		self.state = streamReadUIntN(streamId, 2)

		if self.state == SellPlaceableEvent.STATE_SUCCESS then
			self.sellPrice = streamReadInt32(streamId)
		end
	end

	self:run(connection)
end

function SellPlaceableEvent:writeStream(streamId, connection)
	if connection:getIsServer() then
		NetworkUtil.writeNodeObject(streamId, self.placeable)
		streamWriteBool(streamId, self.forFree)
		streamWriteBool(streamId, self.forFullPrice)
	else
		streamWriteUIntN(streamId, self.state, 2)

		if self.state == SellPlaceableEvent.STATE_SUCCESS then
			streamWriteInt32(streamId, self.sellPrice)
		end
	end
end

function SellPlaceableEvent:run(connection)
	if not connection:getIsServer() then
		local state = SellPlaceableEvent.STATE_FAILED
		local sellPrice = 0

		if self.placeable ~= nil then
			if g_currentMission:getHasPlayerPermission("sellPlaceable", connection) then
				if self.placeable:canBeSold() then
					self.placeable:onSell()

					if not self.forFree then
						if self.forFullPrice then
							sellPrice = self.placeable.price
						else
							sellPrice = self.placeable:getSellPrice()
						end
					end

					state = SellPlaceableEvent.STATE_SUCCESS

					g_currentMission:addMoney(sellPrice, self.placeable:getOwnerFarmId(), MoneyType.SHOP_PROPERTY_SELL, true, true)

					if self.placeable:getSellAction() == Placeable.SELL_AND_SPECTATOR_FARM then
						self.placeable:setOwnerFarmId(FarmManager.SPECTATOR_FARM_ID)
					else
						g_currentMission:addPlaceableToDelete(self.placeable)
					end
				else
					state = SellPlaceableEvent.STATE_IN_USE
				end
			else
				state = SellPlaceableEvent.STATE_NO_PERMISSION
			end
		end

		g_messageCenter:publish(SellPlaceableEvent, state, sellPrice)
		connection:sendEvent(SellPlaceableEvent.newServerToClient(state, sellPrice))
	else
		g_messageCenter:publish(SellPlaceableEvent, self.state, self.sellPrice)
	end
end
