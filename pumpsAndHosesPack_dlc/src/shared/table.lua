table.map = table.map or function (list, predicate, ...)
	local result = {}

	for index, value in ipairs(list) do
		result[index] = predicate(value, ...)
	end

	return result
end
table.swap = table.swap or function (list)
	local result = {}

	for key, value in ipairs(list) do
		result[value] = key
	end

	return result
end
table.reduce = table.reduce or function (list, identity, accumulator, ...)
	local result = identity

	for _, value in ipairs(list) do
		result = accumulator(result, value, ...)
	end

	return result
end
table.first = table.first or function (list)
	return list[1]
end
table.last = table.last or function (list)
	return list[#list]
end
