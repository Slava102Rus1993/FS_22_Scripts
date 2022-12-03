PurchaseSoilMapsEvent = {}
local PurchaseSoilMapsEvent_mt = Class(PurchaseSoilMapsEvent, Event)

InitEventClass(PurchaseSoilMapsEvent, "PurchaseSoilMapsEvent")

function PurchaseSoilMapsEvent:emptyNew()
	local self = Event.new(PurchaseSoilMapsEvent_mt)

	return self
end

function PurchaseSoilMapsEvent.new(farmlandId)
	local self = PurchaseSoilMapsEvent:emptyNew()
	self.farmlandId = farmlandId

	return self
end

function PurchaseSoilMapsEvent:readStream(streamId, connection)
	self.farmlandId = streamReadUIntN(streamId, 8)

	self:run(connection)
end

function PurchaseSoilMapsEvent:writeStream(streamId, connection)
	streamWriteUIntN(streamId, self.farmlandId, 8)
end

function PurchaseSoilMapsEvent:run(connection)
	if not connection:getIsServer() and g_precisionFarming ~= nil and g_precisionFarming.soilMap ~= nil then
		g_precisionFarming.soilMap:purchaseSoilMaps(self.farmlandId)
		g_precisionFarming:updatePrecisionFarmingOverlays()
	end
end
