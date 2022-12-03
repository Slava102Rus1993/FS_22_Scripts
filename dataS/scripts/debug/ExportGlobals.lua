local exportFilenameRaw = "exportedGlobals.txt"
local exportFilenameStrings = "exportedGlobalsStrings.txt"
local maxLineLength = 180
local ignore = {
	string = true,
	math = true,
	table = true
}
local engineGlobals = {}

for global in pairs(_G) do
	if ignore[global] ~= true then
		engineGlobals[#engineGlobals + 1] = global
	end
end

table.sort(engineGlobals)
print(#engineGlobals .. " globals found")
print("saving to " .. exportFilenameRaw)

if fileExists(exportFilenameRaw) then
	deleteFile(exportFilenameRaw)
end

if fileExists(exportFilenameStrings) then
	deleteFile(exportFilenameStrings)
end

local fileRaw = createFile(exportFilenameRaw, FileAccess.WRITE)
local fileListOfString = createFile(exportFilenameStrings, FileAccess.WRITE)
local line = ""

for _, global in ipairs(engineGlobals) do
	if maxLineLength < line:len() then
		fileWrite(fileListOfString, line .. "\n")

		line = ""
	end

	line = line .. string.format("\"%s\", ", global)

	fileWrite(fileRaw, global .. "\n")
end

fileWrite(fileListOfString, line .. "\n")
delete(fileRaw)
delete(fileListOfString)
print("saved raw globals to " .. exportFilenameRaw)
print("saved globals to " .. exportFilenameStrings)
print("exiting")
requestExit()
