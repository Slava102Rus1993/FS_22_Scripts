Queue = {}
local Queue_mt = Class(Queue)

function Queue:new()
	return setmetatable({
		list = {}
	}, Queue_mt)
end

function Queue:push(item)
	table.insert(self.list, item)
end

function Queue:pop()
	return table.remove(self.list, 1)
end

function Queue:isEmpty()
	return #self.list == 0
end

function Queue:size()
	return #self.list
end

function Queue:clear()
	self.list = {}
end

function Queue.fromList(list)
	local queue = Queue:new()
	queue.list = list

	return queue
end
