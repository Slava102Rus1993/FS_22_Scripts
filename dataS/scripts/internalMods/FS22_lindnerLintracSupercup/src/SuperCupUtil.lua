SuperCupUtil = {
	addToListIfNotExists = function (item, list)
		if item == nil then
			return
		end

		if not table.hasElement(list, item) then
			table.addElement(list, item)
		end
	end,
	getClassObject = function (className)
		local parts = string.split(className, ".")
		local numParts = table.getn(parts)
		local currentTable = _G[parts[1]]

		if type(currentTable) ~= "table" then
			return nil
		end

		for i = 2, numParts do
			currentTable = currentTable[parts[i]]

			if type(currentTable) ~= "table" then
				return nil
			end
		end

		return currentTable
	end,
	millisecondsToClockString = function (milliseconds)
		milliseconds = tonumber(milliseconds)

		if milliseconds <= 0 then
			return "--:--:--"
		end

		local millis = milliseconds % 1000
		local t = milliseconds * 0.001
		local seconds = t % 60
		t = t / 60
		local minutes = t % 60

		return ("%02d:%02d:%03d"):format(minutes, seconds, millis)
	end
}
