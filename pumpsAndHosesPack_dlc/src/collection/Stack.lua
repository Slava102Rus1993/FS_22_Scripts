Stack = {}
local Stack_mt = Class(Stack)

function Stack.new(fromList)
	local self = setmetatable({}, Stack_mt)
	self.stack = fromList or {}

	return self
end

function Stack:push(value)
	self.stack[#self.stack + 1] = value
end

function Stack:pop()
	return table.remove(self.stack, #self.stack)
end

function Stack:first()
	return self.stack[#self.stack]
end

function Stack:size()
	return #self.stack
end
