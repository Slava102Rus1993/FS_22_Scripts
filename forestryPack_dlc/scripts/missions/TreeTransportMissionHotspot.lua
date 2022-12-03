local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

TreeTransportMissionHotspot = {
	MOD_DIRECTORY = g_currentModDirectory
}
local TreeTransportMissionHotspot_mt = Class(TreeTransportMissionHotspot, MapHotspot)

function TreeTransportMissionHotspot.new(customMt)
	local self = MapHotspot.new(customMt or TreeTransportMissionHotspot_mt)
	self.width, self.height = getNormalizedScreenValues(50, 50)
	local filename = Utils.getFilename("menu/hud/treeTransportHotspot.png", TreeTransportMissionHotspot.MOD_DIRECTORY)
	local uvs = GuiUtils.getUVs({
		13,
		13,
		103,
		103
	}, {
		128,
		128
	})
	self.icon = Overlay.new(filename, 0, 0, self.width, self.height)

	self.icon:setUVs(uvs)

	self.forceNoRotation = true

	return self
end

function TreeTransportMissionHotspot:delete()
	TreeTransportMissionHotspot:superClass().delete(self)

	if self.icon ~= nil then
		self.icon:delete()

		self.icon = nil
	end
end

function TreeTransportMissionHotspot:getWidth()
	if self.icon ~= nil then
		return self.icon.width
	end

	return 0
end

function TreeTransportMissionHotspot:getHeight()
	if self.icon ~= nil then
		return self.icon.height
	end

	return 0
end

function TreeTransportMissionHotspot:setScale(scale)
	if self.icon ~= nil then
		self.icon:setScale(scale, scale)
	end
end

function TreeTransportMissionHotspot:getCategory()
	return MapHotspot.CATEGORY_MISSION
end

function TreeTransportMissionHotspot:getIsPersistent()
	return false
end

function TreeTransportMissionHotspot:getRenderLast()
	return false
end

function TreeTransportMissionHotspot:render(x, y, rotation, small)
	local icon = self.icon

	if icon ~= nil then
		icon:setPosition(x, y)
		icon:setColor(nil, , , self.isBlinking and self:getCanBlink() and IngameMap.alpha or 1)
		icon:render()
	end
end
