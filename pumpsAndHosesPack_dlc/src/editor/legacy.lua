g_isEditor = true

function loadEditorLegacy(sourceDirectory)
	source(sourceDirectory .. "src/editor/legacy/game.lua")
	source(sourceDirectory .. "src/main.lua")
	source(sourceDirectory .. "src/editor/legacy/I3DManager.lua")
end
