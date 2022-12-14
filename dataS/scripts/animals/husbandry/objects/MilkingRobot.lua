MilkingRobot = {}
local MilkingRobot_mt = Class(MilkingRobot)

function MilkingRobot.new(owner, baseDirectory, customMt)
	local self = setmetatable({}, customMt or MilkingRobot_mt)
	self.owner = owner
	self.baseDirectory = baseDirectory

	return self
end

function MilkingRobot:load(linkNode, filename, asyncCallbackFunction, asyncCallbackObject, asyncCallbackArgs)
	local xmlFile = XMLFile.load("milkingRobot", filename)

	if xmlFile == nil then
		return false
	end

	local i3dFilename = Utils.getFilename(xmlFile:getString("milkingRobot.filename"), self.baseDirectory)
	local arguments = {
		xmlFile = xmlFile,
		linkNode = linkNode,
		asyncCallbackFunction = asyncCallbackFunction,
		asyncCallbackObject = asyncCallbackObject,
		asyncCallbackArgs = asyncCallbackArgs
	}
	self.sharedLoadRequestId = g_i3DManager:loadSharedI3DFileAsync(i3dFilename, true, false, self.onI3DFileLoaded, self, arguments)

	return true
end

function MilkingRobot:delete()
	if self.sharedLoadRequestId ~= nil then
		g_i3DManager:releaseSharedI3DFile(self.sharedLoadRequestId)

		self.sharedLoadRequestId = nil
	end

	if self.node ~= nil then
		delete(self.node)

		self.node = nil
	end
end

function MilkingRobot:onI3DFileLoaded(node, failedReason, args)
	if node ~= 0 then
		link(args.linkNode, node)

		self.node = node
	end

	args.xmlFile:delete()
	args.asyncCallbackFunction(args.asyncCallbackObject, self, args.asyncCallbackArgs)
end

function MilkingRobot:finalizePlacement()
	if self.node ~= nil then
		addToPhysics(self.node)
	end
end
