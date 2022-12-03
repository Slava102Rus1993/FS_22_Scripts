InGameMenuHelpFrame = {}
local InGameMenuHelpFrame_mt = Class(InGameMenuHelpFrame, TabbedMenuFrameElement)
InGameMenuHelpFrame.CONTROLS = {
	"helpLineList",
	"helpLineTitleElement",
	"helpLineContentBox",
	"helpLineContentItem",
	"helpLineContentItemTitle"
}

function InGameMenuHelpFrame.new(subclass_mt, l10n, helpLineManager)
	local self = InGameMenuHelpFrame:superClass().new(nil, subclass_mt or InGameMenuHelpFrame_mt)

	self:registerControls(InGameMenuHelpFrame.CONTROLS)

	self.l10n = l10n
	self.helpLineManager = helpLineManager

	return self
end

function InGameMenuHelpFrame.createFromExistingGui(gui, guiName)
	local newGui = InGameMenuHelpFrame.new(nil, gui.l10n, gui.helpLineManager)

	g_gui.frames[gui.name].target:delete()
	g_gui.frames[gui.name]:delete()
	g_gui:loadGui(gui.xmlFilename, guiName, newGui, true)

	return newGui
end

function InGameMenuHelpFrame:copyAttributes(src)
	InGameMenuHelpFrame:superClass().copyAttributes(self, src)

	self.l10n = src.l10n
	self.helpLineManager = src.helpLineManager
end

function InGameMenuHelpFrame:onGuiSetupFinished()
	InGameMenuHelpFrame:superClass().onGuiSetupFinished(self)
	self.helpLineList:setDataSource(self)
	self.helpLineList:setDelegate(self)
end

function InGameMenuHelpFrame:delete()
	self.helpLineContentItem:delete()
	self.helpLineContentItemTitle:delete()
	InGameMenuHelpFrame:superClass().delete(self)
end

function InGameMenuHelpFrame:onFrameOpen()
	InGameMenuHelpFrame:superClass().onFrameOpen(self)
	self.helpLineList:reloadData()
	self:setSoundSuppressed(true)
	FocusManager:setFocus(self.helpLineList)
	self:setSoundSuppressed(false)
	self.helpLineContentBox:registerActionEvents()
end

function InGameMenuHelpFrame:onFrameClose()
	self.helpLineContentBox:removeActionEvents()
	InGameMenuHelpFrame:superClass().onFrameClose(self)
end

function InGameMenuHelpFrame:updateContents(page)
	self.helpLineContentItem:unlinkElement()
	self.helpLineContentItemTitle:unlinkElement()

	for i = #self.helpLineContentBox.elements, 1, -1 do
		self.helpLineContentBox.elements[i]:delete()
	end

	self.helpLineContentBox:invalidateLayout()

	if page == nil then
		return
	end

	self.helpLineTitleElement:setText(self.helpLineManager:convertText(page.title, page.customEnvironment))

	for _, paragraph in ipairs(page.paragraphs) do
		if paragraph.title ~= nil then
			local titleElement = self.helpLineContentItemTitle:clone(self.helpLineContentBox)

			titleElement:setText(g_helpLineManager:convertText(paragraph.title, paragraph.customEnvironment))
		end

		local row = self.helpLineContentItem:clone(self.helpLineContentBox)
		local textElement = row:getDescendantByName("text")
		local textFullElement = row:getDescendantByName("textFullWidth")
		local imageElement = row:getDescendantByName("image")
		local textHeight = 0
		local textHeightFullHeight = 0

		if paragraph.noSpacing then
			row.margin = {
				0,
				0,
				0,
				0
			}
		end

		if paragraph.image ~= nil then
			textFullElement:setVisible(false)

			if paragraph.text ~= nil then
				textElement:setText(self.helpLineManager:convertText(paragraph.text, paragraph.customEnvironment))

				textHeight = textElement:getTextHeight(true)

				textElement:setSize(nil, textHeight)
			end

			local filename = Utils.getFilename(paragraph.image.filename, paragraph.baseDirectory)

			imageElement:setImageFilename(filename)
			imageElement:setImageUVs(nil, unpack(paragraph.image.uvs))

			if imageElement.originalWidth == nil then
				imageElement.originalWidth = imageElement.absSize[1]
			end

			if paragraph.image.displaySize ~= nil then
				imageElement:setSize(paragraph.image.displaySize[1], paragraph.image.displaySize[2])
			elseif paragraph.text == nil then
				imageElement:setSize(row.absSize[1], row.absSize[1] * paragraph.image.aspectRatio * g_screenAspectRatio)
			else
				imageElement:setSize(imageElement.originalWidth, nil)
			end

			if paragraph.text ~= nil and paragraph.alignToImage then
				textElement:setSize(nil, imageElement.size[2])

				textElement.textVerticalAlignment = TextElement.VERTICAL_ALIGNMENT.MIDDLE
			end
		else
			textElement:setVisible(false)
			imageElement:setVisible(false)

			if paragraph.text ~= nil then
				textFullElement:setText(self.helpLineManager:convertText(paragraph.text, paragraph.customEnvironment))
			end

			textHeightFullHeight = textFullElement:getTextHeight(true)

			textFullElement:setSize(nil, textHeightFullHeight)
		end

		local imageHeight = paragraph.image ~= nil and imageElement.absSize[2] or 0

		row:setSize(nil, math.max(textHeight, textHeightFullHeight, imageHeight))
		row:invalidateLayout()
	end

	self.helpLineContentBox:invalidateLayout()
end

function InGameMenuHelpFrame:onListSelectionChanged(list, section, index)
	self:updateContents(self:getPage(section, index))
end

function InGameMenuHelpFrame:getNumberOfSections()
	return #self.helpLineManager.categories
end

function InGameMenuHelpFrame:getNumberOfItemsInSection(list, section)
	return #self.helpLineManager.categories[section].pages
end

function InGameMenuHelpFrame:getTitleForSectionHeader(list, section)
	local sectionData = self.helpLineManager.categories[section]

	return self.l10n:convertText(sectionData.title, sectionData.customEnvironment)
end

function InGameMenuHelpFrame:populateCellForItemInSection(list, section, index, cell)
	local page = self:getPage(section, index)

	cell:getAttribute("title"):setText(self.l10n:convertText(page.title, page.customEnvironment))
end

function InGameMenuHelpFrame:getPage(categoryIndex, pageIndex)
	local categories = self.helpLineManager:getCategories()

	return categories[categoryIndex].pages[pageIndex]
end

function InGameMenuHelpFrame:openPage(categoryIndex, pageIndex)
	self:setSoundSuppressed(true)
	self.helpLineList:setSelectedItem(categoryIndex, pageIndex, true, 1)
	self:setSoundSuppressed(false)
end
