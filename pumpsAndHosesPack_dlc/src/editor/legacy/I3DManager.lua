I3DManager = class("I3DManager")
I3DManager.files = {}

function I3DManager:loadSharedI3DFileAsync(filename, callOnCreate, addToPhysics, callback, target, args)
	callOnCreate = callOnCreate or false
	addToPhysics = addToPhysics or false
	local file = I3DManager.files[filename]

	if file == nil then
		file = {
			nodeId = loadI3DFile(filename, false, false, true)
		}
		I3DManager.files[filename] = file
	end

	if file.nodeId == 0 then
		log("Error: failed to load i3d file '" .. filename .. "'")

		return 0
	end

	local node = clone(file.nodeId, false, callOnCreate, addToPhysics)

	callback(target, node, nil, args)
end
