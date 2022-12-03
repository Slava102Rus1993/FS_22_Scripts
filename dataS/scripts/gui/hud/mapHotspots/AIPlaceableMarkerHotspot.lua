AIPlaceableMarkerHotspot = {
	FILE_RESOLUTION = {
		1024,
		512
	}
}
AIPlaceableMarkerHotspot.UVS = GuiUtils.getUVs({
	760,
	111,
	100,
	100
}, AIPlaceableMarkerHotspot.FILE_RESOLUTION)
AIPlaceableMarkerHotspot.FILENAME = "dataS/menu/hud/mapHotspots.png"
local AIPlaceableMarkerHotspot_mt = Class(AIPlaceableMarkerHotspot, MapHotspot)

function AIPlaceableMarkerHotspot.new(customMt)
	local self = MapHotspot.new(customMt or AIPlaceableMarkerHotspot_mt)
	self.width, self.height = getNormalizedScreenValues(60, 60)
	self.icon = Overlay.new(AIPlaceableMarkerHotspot.FILENAME, 0, 0, self.width, self.height)

	self.icon:setUVs(AIPlaceableMarkerHotspot.UVS)

	self.isBlinking = true

	return self
end

function AIPlaceableMarkerHotspot:getCategory()
	return MapHotspot.CATEGORY_AI
end

function AIPlaceableMarkerHotspot:getIsPersistent()
	return true
end

function AIPlaceableMarkerHotspot:getRenderLast()
	return true
end
