I3DCacheEntry = class("I3DCacheEntry")

function I3DCacheEntry:construct(node, filename)
	self.cache = self:create(node)
	self.filename = filename
end

function I3DCacheEntry:create(node)
	return {
		node = node
	}
end

function I3DCacheEntry:delete()
	delete(self.cache.node)
end

function I3DCacheEntry:clone()
	local cloneNode = clone(self.cache.node, false, false, false)

	return {
		node = cloneNode
	}
end
