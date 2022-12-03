function log(...)
	local str = ""

	for i = 1, select("#", ...) do
		str = str .. " " .. tostring(select(i, ...))
	end

	print(str)
end

function rotate(name, dx, dy, dz)
	local x, y, z = getRotation(name)

	setRotation(name, x + dx, y + dy, z + dz)
end

function rotate(name, dx, dy, dz)
	local x, y, z = getRotation(name)

	setRotation(name, x + dx, y + dy, z + dz)
end

function getCorrectTextSize(size)
	if g_aspectScaleY == nil then
		return size
	else
		return size * g_aspectScaleY
	end
end

function Class(members, baseClass)
	members = members or {}
	local __index = members
	local mt = {
		__metatable = members,
		__index = __index
	}

	if baseClass ~= nil then
		setmetatable(members, {
			__index = baseClass
		})
	end

	local function new(_, init)
		return setmetatable(init or {}, mt)
	end

	local function copy(obj, ...)
		local newobj = obj.new(unpack(arg))

		for n, v in pairs(obj) do
			newobj[n] = v
		end

		return newobj
	end

	function members:class()
		return members
	end

	function members:superClass()
		return baseClass
	end

	function members:isa(other)
		local curClass = members

		while curClass ~= nil do
			if curClass == other then
				return true
			else
				curClass = curClass:superClass()
			end
		end

		return false
	end

	members.new = members.new or new
	members.copy = members.copy or copy

	return mt
end

Utils = {
	getFilename = function (filename, baseDir)
		if filename == nil then
			printCallstack()

			return nil
		end

		if type(filename) == "boolean" then
			printCallstack()
		end

		if filename:sub(1, 1) == "$" then
			return filename:sub(2), false
		elseif baseDir == nil or baseDir == "" then
			return filename, false
		elseif filename == "" then
			return filename, true
		end

		return baseDir .. filename, true
	end,
	renderTextAtWorldPosition = function (x, y, z, text, textSize, textOffset, color)
		local sx, sy, sz = project(x, y, z)
		color = color or {
			0.5,
			1,
			0.5,
			1
		}

		if sx > -1 and sx < 2 and sy > -1 and sy < 2 and sz <= 1 then
			local r, g, b, a = unpack(color)

			setTextAlignment(RenderText.ALIGN_CENTER)
			setTextBold(false)
			setTextColor(0, 0, 0, 0.75)
			renderText(sx, sy - 0.0015 + textOffset, textSize, text)
			setTextColor(r, g, b, a or 1)
			renderText(sx, sy + textOffset, textSize, text)
			setTextAlignment(RenderText.ALIGN_LEFT)
			setTextColor(1, 1, 1, 1)
		end
	end
}
I3DUtil = {
	indexToObject = function (components, index)
		return getChildAt(components, index)
	end,
	setWorldDirection = function (node, dirX, dirY, dirZ, upX, upY, upZ, limitedAxis, minRot, maxRot)
		local parent = getParent(node)

		if dirX ~= dirX or dirY ~= dirY or dirZ ~= dirZ then
			Logging.error("Failed to set world direction: Object '%s' dir %.2f %.2f %.2f up %.2f %.2f %.2f", getName(node), dirX, dirY, dirZ, upX, upY, upZ)

			return
		end

		if parent ~= 0 then
			dirX, dirY, dirZ = worldDirectionToLocal(parent, dirX, dirY, dirZ)
			upX, upY, upZ = worldDirectionToLocal(parent, upX, upY, upZ)
		end

		if limitedAxis ~= nil then
			if limitedAxis == 1 then
				dirX = 0

				if minRot ~= nil then
					dirZ, dirY = MathUtil.getRotationLimitedVector2(dirZ, dirY, minRot, maxRot)
				end
			elseif limitedAxis == 2 then
				dirY = 0

				if minRot ~= nil then
					dirZ, dirX = MathUtil.getRotationLimitedVector2(dirZ, dirX, minRot, maxRot)
				end
			else
				dirZ = 0

				if minRot ~= nil then
					dirX, dirY = MathUtil.getRotationLimitedVector2(dirX, dirY, minRot, maxRot)
				end
			end
		end

		if dirX * dirX + dirY * dirY + dirZ * dirZ > 0.0001 then
			setDirection(node, dirX, dirY, dirZ, upX, upY, upZ)
		end
	end
}
