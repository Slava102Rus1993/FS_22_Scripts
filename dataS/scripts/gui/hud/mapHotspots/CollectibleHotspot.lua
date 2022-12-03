CollectibleHotspot = {}
local CollectibleHotspot_mt = Class(CollectibleHotspot, MapHotspot)

function CollectibleHotspot.new(collectible)
	local self = MapHotspot.new(CollectibleHotspot_mt)
	self.width, self.height = getNormalizedScreenValues(40, 40)
	self.icon = Overlay.new(PlaceableHotspot.FILENAME, 0, 0, self.width, self.height)

	self.icon:setUVs(GuiUtils.getUVs({
		652,
		4,
		100,
		100
	}, PlaceableHotspot.FILE_RESOLUTION))

	self.color[1] = 0.8
	self.color[2] = 0.5
	self.color[3] = 0
	local _ = nil
	self.worldX, _, self.worldZ = getWorldTranslation(collectible.node)

	return self
end

function CollectibleHotspot:getCategory()
	return MapHotspot.CATEGORY_OTHER
end
