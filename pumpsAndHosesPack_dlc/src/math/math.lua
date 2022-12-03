math.round = math.round or function (x, idp)
	return tonumber(string.format("%." .. (idp or 0) .. "f", x))
end
math.booltointeger = math.booltointeger or function (x)
	return x and 1 or 0
end
math.booltodirection = math.booltodirection or function (x)
	return x and 1 or -1
end
math.clamp = math.clamp or function (x, min, max)
	return math.min(math.max(x, min), max)
end
