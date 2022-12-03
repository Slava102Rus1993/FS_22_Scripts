AudioGroup = {
	groups = {}
}

function AudioGroup.getAudioGroupIndexByName(name)
	if name ~= nil then
		name = name:upper()

		return AudioGroup[name]
	end

	return nil
end

function AudioGroup.getAudioGroupNameByIndex(index)
	if index ~= nil then
		for name, id in pairs(AudioGroup) do
			if index == id then
				return name
			end
		end
	end

	return nil
end

function AudioGroup.getIsValidAudioGroup(audioGroupIndex)
	for _, index in pairs(AudioGroup) do
		if index == audioGroupIndex then
			return true
		end
	end

	return false
end

function AudioGroup.loadGroups()
	local xmlFile = loadXMLFile("AudioGroups", "shared/audioGroups.xml")

	if xmlFile == 0 then
		Logging.error("Failed to load audio groups!")

		return
	end

	local i = 0

	while true do
		local key = string.format("audioGroups.audioGroup(%d)", i)

		if not hasXMLProperty(xmlFile, key) then
			break
		end

		local id = getXMLInt(xmlFile, key .. "#id")
		local name = getXMLString(xmlFile, key .. "#name")

		if id ~= nil then
			if name ~= nil then
				name = name:upper()

				if AudioGroup[name] == nil then
					local found = false

					for k, v in pairs(AudioGroup) do
						if v == id then
							found = true

							break
						end
					end

					if not found then
						AudioGroup[name] = id

						table.insert(AudioGroup.groups, AudioGroup[name])
					else
						Logging.xmlError(xmlFile, "AudioGroup id '%d' already defined in '%s'!", id, key)
					end
				else
					Logging.xmlError(xmlFile, "AudioGroup '%s' already defined in '%s'!", name, key)
				end
			else
				Logging.xmlError(xmlFile, "Missing name for audio group '%s'!", key)
			end
		else
			Logging.xmlError(xmlFile, "Missing id for audio group '%s'!", key)
		end

		i = i + 1
	end

	delete(xmlFile)
end
