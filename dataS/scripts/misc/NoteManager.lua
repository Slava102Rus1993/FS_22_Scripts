NoteManager = {
	NOTES_DIRECTORY = getUserProfileAppPath() .. "notes/"
}
local NoteManager_mt = Class(NoteManager, AbstractManager)

function NoteManager.new(customMt)
	local self = AbstractManager.new(customMt or NoteManager_mt)

	return self
end

function NoteManager:initDataStructures()
	self.sessionDirectory = nil
	self.sessionTimestamp = nil
	self.mapTitle = nil
	self.currentNoteIndex = 1
	local colorWhite = {
		1,
		1,
		1,
		1
	}
	self.colors = {}

	table.insert(self.colors, {
		color = colorWhite
	})

	for _, color in ipairs(DebugUtil.COLORS) do
		table.insert(self.colors, {
			color = {
				color[1],
				color[2],
				color[3],
				1
			}
		})
	end

	self.lastColor = colorWhite

	if not self.initialized then
		addConsoleCommand("gsNoteExport", "Exports currently created note nodes as i3d file", "consoleCommandExportNotes", self)
		addConsoleCommand("gsNoteList", "Lists currently created note nodes in console/log", "consoleCommandListNotes", self)

		self.initialized = true
	end
end

function NoteManager:registerInputActionEvent()
	if g_currentMission ~= nil then
		local _, eventId = g_inputBinding:registerActionEvent(InputAction.ADD_NOTE, self, self.onAddNote, false, true, false, true)

		g_inputBinding:setActionEventTextVisibility(eventId, false)
	end
end

function NoteManager:unloadMapData()
	self:exportNotes()
	self:resetNotes()
end

function NoteManager:resetNotes()
	if self.notesRoot ~= nil and entityExists(self.notesRoot) then
		delete(self.notesRoot)
	end

	self.notesRoot = nil
	self.sessionDirectory = nil
	self.currentNoteIndex = 1
end

function NoteManager:loadNotes()
end

function NoteManager:onAddNote()
	if self.sessionDirectory == nil then
		createFolder(NoteManager.NOTES_DIRECTORY)

		self.mapTitle = string.gsub(g_currentMission.missionInfo.mapTitle, " ", "")
		self.sessionTimestamp = getDate("%Y_%m_%d__%H_%M")
		self.sessionDirectory = NoteManager.NOTES_DIRECTORY .. self.sessionTimestamp .. "_" .. self.mapTitle .. "/"

		createFolder(self.sessionDirectory)
	end

	local filename = string.format("note_%d.jpg", self.currentNoteIndex)
	self.lastNoteScreenshotFilepath = self.sessionDirectory .. filename

	saveScreenshot(self.lastNoteScreenshotFilepath)
	g_gui:showTextInputDialog({
		confirmText = "Add Note",
		maxCharacters = 200,
		dialogPrompt = "Enter note text",
		target = self,
		callback = self.onNoteTextEntered
	})
end

function NoteManager:onNoteTextEntered(text, ok)
	if ok then
		text = string.trim(text)

		if text ~= "" then
			g_gui:showColorPickerDialog({
				target = self,
				callback = self.onNotePickColor,
				colors = self.colors,
				defaultColor = self.lastColor,
				args = {
					colors = self.colors,
					colorOptionIndex = self.lastColor,
					text = text
				}
			})

			return
		end
	end

	self:cancelCurrentNote()
end

function NoteManager:onNotePickColor(colorIndex, args)
	if colorIndex == nil then
		self:cancelCurrentNote()

		return
	end

	if self.notesRoot == nil then
		self.notesRoot = createTransformGroup("noteNodes")

		link(getRootNode(), self.notesRoot)
	end

	local color = args.colors[colorIndex].color
	self.lastColor = color
	local note = createNoteNode(self.notesRoot, string.format("[%d] %s", self.currentNoteIndex, args.text), color[1], color[2], color[3], false)

	setName(note, string.format("note_%d", self.currentNoteIndex))

	if g_isDevelopmentVersion and self.currentNoteIndex == 1 then
		executeConsoleCommand("enableNoteRendering true")
	end

	self.currentNoteIndex = self.currentNoteIndex + 1

	Logging.info("created note '%s' at %.1f %.1f %.1f", getNoteNodeText(note), getWorldTranslation(note))

	self.lastNoteScreenshotFilepath = nil
end

function NoteManager:cancelCurrentNote()
	if self.lastNoteScreenshotFilepath ~= nil and fileExists(self.lastNoteScreenshotFilepath) then
		deleteFile(self.lastNoteScreenshotFilepath)
	end
end

function NoteManager:exportNotes()
	if self.notesRoot == nil then
		return 0
	end

	local filename = string.format("notes_%s_%s.i3d", self.sessionTimestamp, self.mapTitle)
	local filepath = self.sessionDirectory .. filename

	Logging.info("Exporting notes to %s", filepath)
	exportNoteNodes(filepath)

	local numNotes = getNumOfChildren(self.notesRoot)

	return numNotes
end

function NoteManager:consoleCommandExportNotes()
	if self.notesRoot == nil then
		return "Error: No notes to export, add notes first"
	end

	return string.format("Exported %d notes", self:exportNotes())
end

function NoteManager:consoleCommandListNotes()
	if self.notesRoot == nil then
		return "No existing notes"
	end

	local numNotes = getNumOfChildren(self.notesRoot)

	for i = 0, numNotes - 1 do
		local noteNode = getChildAt(self.notesRoot, i)
		local wx, wy, wz = getWorldTranslation(noteNode)

		print(string.format("%s [Pos: %.1f %1.f %1.f]", getNoteNodeText(noteNode), wx, wy, wz))
	end

	return string.format("Listed %d notes", numNotes)
end

g_noteManager = NoteManager.new()
