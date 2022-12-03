local mt = {}
class = setmetatable({}, mt)
class.__name = "class"
class.__index = class

function mt.__call(root, super, name)
	super = super or root

	if super ~= nil and name == nil and type(super) == "string" then
		name = super
		super = root
	end

	local c = setmetatable({}, super)
	c.__index = c
	c.__call = root.__call
	c.__name = name or "unknown"
	c._super = super

	function c:class()
		return c
	end

	return c
end

function class.__call(cls, ...)
	local obj = setmetatable({}, cls)
	obj._class = cls

	obj:construct(...)

	return obj
end

function class:construct(...)
end

function class:superClass()
	return self._super
end

function class:classname()
	return self.__name
end

function class:copy(...)
	local newobj = self(table.unpack({
		...
	}))

	for n, v in pairs(self) do
		newobj[n] = v
	end

	return newobj
end

function class:isa(cls)
	cls = cls or class
	local c = self:class()

	while c ~= nil do
		if c == cls then
			return true
		end

		c = c:superClass()
	end

	return false
end
