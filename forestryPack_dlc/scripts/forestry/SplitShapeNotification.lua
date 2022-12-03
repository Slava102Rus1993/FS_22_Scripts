local _, _, isDlc, _ = Utils.removeModDirectory(g_currentModDirectory)

if not isDlc or g_currentModName ~= "pdlc_forestryPack" then
	return
end

SplitShapeNotification = {
	SPLIT_SHAPES = {},
	callbackFunc = nil,
	callbackTarget = nil
}
local originalSplitFunc = splitShape

function SplitShapeNotification.onSplitShapeCallback(unused, shape, isBelow, isAbove, minY, maxY, minZ, maxZ)
	local splitData = {
		shape = shape,
		isBelow = isBelow,
		isAbove = isAbove,
		minY = minY,
		maxY = maxY,
		minZ = minZ,
		maxZ = maxZ
	}

	table.insert(SplitShapeNotification.SPLIT_SHAPES, splitData)

	local target = SplitShapeNotification.callbackTarget
	local callbackFunc = SplitShapeNotification.callbackFunc

	target[callbackFunc](target, shape, isBelow, isAbove, minY, maxY, minZ, maxZ)
end

function SplitShapeNotification.splitShape(shape, x, y, z, nx, ny, nz, yx, yy, yz, cutSizeY, cutSizeZ, callback, target)
	local tx, ty, tz = getWorldTranslation(shape)
	local rx, ry, rz = getWorldRotation(shape)
	local data = {
		shape = shape,
		splitType = getSplitType(shape),
		volume = getVolume(shape),
		x = tx,
		y = ty,
		z = tz,
		rx = rx,
		ry = ry,
		rz = rz,
		alreadySplit = getIsSplitShapeSplit(shape)
	}

	if target == nil then
		local parts = string.split(callback, ".")

		if #parts == 2 then
			target = _G[parts[1]]
			callback = parts[2]
		end
	end

	SplitShapeNotification.callbackFunc = callback
	SplitShapeNotification.callbackTarget = target
	SplitShapeNotification.SPLIT_SHAPES = {}

	originalSplitFunc(shape, x, y, z, nx, ny, nz, yx, yy, yz, cutSizeY, cutSizeZ, "onSplitShapeCallback", SplitShapeNotification)
	g_messageCenter:publish(MessageType.SPLIT_SHAPE, data, SplitShapeNotification.SPLIT_SHAPES)
end

function _G.splitShape(shape, x, y, z, nx, ny, nz, yx, yy, yz, cutSizeY, cutSizeZ, callback, target)
	SplitShapeNotification.splitShape(shape, x, y, z, nx, ny, nz, yx, yy, yz, cutSizeY, cutSizeZ, callback, target)
end
