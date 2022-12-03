AdsSystem = {}
local AdsSystem_mt = Class(AdsSystem)
AdsSystem.OCCLUSION_GROUP = {
	UI = 0
}

function AdsSystem.new()
	local self = setmetatable({}, AdsSystem_mt)
	self.groups = {}
	local numGroups = 0

	for name, id in pairs(AdsSystem.OCCLUSION_GROUP) do
		if numGroups == 32 then
			Logging.warning("AdsSystem: Occclusion group limit (32) reached!")

			break
		end

		self.groups[id] = {
			isActive = false,
			id = id,
			name = name,
			regions = {}
		}
		numGroups = numGroups + 1
	end

	if g_isDevelopmentVersion then
		addConsoleCommand("gsAdsSystemShowOcclusionRegions", "Renders occlusion areas", "consoleCommandShowOcclusionRegions", self)
	end

	self.renderOcclusionRegions = false

	return self
end

function AdsSystem:delete()
	removeConsoleCommand("gsAdsSystemShowOcclusionRegions")

	self.groups = {}
end

function AdsSystem:draw()
	if self.renderOcclusionRegions then
		for _, group in pairs(self.groups) do
			local groupId = group.id

			if adsGetIsOcclusionRegionGroupActive(groupId) then
				for k, region in ipairs(group.regions) do
					local minX, minY, maxX, maxY = adsGetOcclusionRegion(groupId, k - 1)

					drawFilledRect(minX, minY, maxX - minX, maxY - minY, 1, 0, 0, 0.3, nil, , , )
					setTextColor(1, 1, 1, 1)
					setTextAlignment(RenderText.ALIGN_LEFT)

					local offsetX = 5 / g_screenWidth
					local offsetY = 5 / g_screenHeight

					renderText(minX + offsetX, minY + offsetY, 0.02, tostring(group.name))
				end
			end
		end
	end
end

function AdsSystem:clearGroupRegion(groupId)
	local group = self.groups[groupId]

	if group ~= nil then
		group.regions = {}

		adsClearOcclusionRegionGroup(groupId)

		return true
	end

	Logging.warning("AdsSystem: GroupId '%s' not defined!", tostring(groupId))

	return false
end

function AdsSystem:addGroupRegion(groupId, x, y, width, height)
	local group = self.groups[groupId]

	if group ~= nil then
		if #group.regions == 4 then
			Logging.warning("AdsSystem: Region limit (4) per group already reached!")

			return false
		end

		local region = {
			x = x,
			y = y,
			width = width,
			height = height
		}

		table.insert(group.regions, region)
		adsAddOcclusionRegion(groupId, x, y, x + width, y + height)

		return true
	end

	Logging.warning("AdsSystem: GroupId '%s' not defined!", tostring(groupId))

	return false
end

function AdsSystem:setGroupActive(groupId, isActive)
	local group = self.groups[groupId]

	if group ~= nil then
		group.isActive = isActive

		adsSetIsOcclusionRegionGroupActive(groupId, isActive)

		return false
	end

	Logging.warning("AdsSystem: GroupId '%s' not defined!", tostring(groupId))

	return false
end

function AdsSystem:consoleCommandShowOcclusionRegions()
	self.renderOcclusionRegions = not self.renderOcclusionRegions
end
