NetworkHelper = {}

function NetworkHelper.writeCompressedLinearColor(streamId, color)
	return NetworkHelper.writeCompressedLinearRgb(streamId, color[1], color[2], color[3])
end

function NetworkHelper.readCompressedLinearColor(streamId)
	local r, g, b = NetworkHelper.readCompressedLinearRgb(streamId)

	return {
		r,
		g,
		b
	}
end

function NetworkHelper.writeCompressedLinearRgb(streamId, r, g, b)
	local function unnormalize(color)
		return color^0.45454545454545453 * 255
	end

	local compressed = unnormalize(r)
	compressed = bitShiftLeft(compressed, 8) + unnormalize(g)
	compressed = bitShiftLeft(compressed, 8) + unnormalize(b)

	streamWriteInt32(streamId, compressed)
end

function NetworkHelper.readCompressedLinearRgb(streamId)
	local compressed = streamReadInt32(streamId)

	local function normalize(color)
		return (color / 255)^2.2
	end

	local r = bitAND(bitShiftRight(compressed, 16), 255)
	local g = bitAND(bitShiftRight(compressed, 8), 255)
	local b = bitAND(compressed, 255)

	return normalize(r), normalize(g), normalize(b)
end

function NetworkHelper.writeUmbilicalHoseConnectorInfo(streamId, connectorInfo)
	local hasInfo = connectorInfo ~= nil

	streamWriteBool(streamId, hasInfo)

	if hasInfo then
		NetworkUtil.writeNodeObject(streamId, connectorInfo.object)
		streamWriteBool(streamId, connectorInfo.isHose)
		streamWriteBool(streamId, connectorInfo.canPerformUpdate)
	end
end

function NetworkHelper.readUmbilicalHoseConnectorInfo(streamId, connectorInfo)
	local hasInfo = streamReadBool(streamId)

	if hasInfo then
		connectorInfo = connectorInfo or {}
		connectorInfo.object = NetworkUtil.readNodeObject(streamId)
		connectorInfo.isHose = streamReadBool(streamId)
		connectorInfo.canPerformUpdate = streamReadBool(streamId)
	end
end
