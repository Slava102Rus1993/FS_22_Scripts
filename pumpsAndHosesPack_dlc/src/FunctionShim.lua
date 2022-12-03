FunctionShim = {}
local originalFunctions = {}

local function storeOriginalFunction(target, name)
	if not GS_IS_CONSOLE_VERSION then
		return
	end

	if originalFunctions[target] == nil then
		originalFunctions[target] = {}
	end

	if originalFunctions[target][name] == nil then
		originalFunctions[target][name] = target[name]
	end
end

function FunctionShim.overwrittenFunction(target, name, newFunc)
	storeOriginalFunction(target, name)

	target[name] = Utils.overwrittenFunction(target[name], newFunc)
end

function FunctionShim.appendedFunction(target, name, newFunc)
	storeOriginalFunction(target, name)

	target[name] = Utils.appendedFunction(target[name], newFunc)
end

function FunctionShim.prependedFunction(target, name, newFunc)
	storeOriginalFunction(target, name)

	target[name] = Utils.prependedFunction(target[name], newFunc)
end

function FunctionShim.resetOriginalFunctions()
	for target, functions in pairs(originalFunctions) do
		for name, func in pairs(functions) do
			target[name] = func
		end
	end
end
