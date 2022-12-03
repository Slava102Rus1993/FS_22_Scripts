RingBuffer = {}
local RingBuffer_mt = Class(RingBuffer)

function RingBuffer.new(size, customMt)
	local self = setmetatable({}, customMt or RingBuffer_mt)
	self.size = size
	self.index = 1
	self.values = {
		0
	}

	return self
end

function RingBuffer:add(value)
	self.values[self.index] = value
	self.index = self.index + 1

	if self.size < self.index then
		self.index = 1
	end
end

function RingBuffer:getAverage()
	local sum = 0

	for _, value in ipairs(self.values) do
		sum = sum + value
	end

	return sum / #self.values
end
