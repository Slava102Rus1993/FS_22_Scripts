ModHubScreenshotDialog = {
	CONTROLS = {
		"list",
		"headerText",
		"selectorLeftGamepad",
		"selectorRightGamepad"
	}
}
local ModHubScreenshotDialog_mt = Class(ModHubScreenshotDialog, DialogElement)

function ModHubScreenshotDialog.new(target, custom_mt)
	local self = DialogElement.new(target, custom_mt or ModHubScreenshotDialog_mt)

	self:registerControls(ModHubScreenshotDialog.CONTROLS)

	return self
end

function ModHubScreenshotDialog:onCreate()
	self.list:setDataSource(self)
end

function ModHubScreenshotDialog:onOpen()
	ModHubScreenshotDialog:superClass().onOpen(self)
	self.list:setSelectedIndex(1)
end

function ModHubScreenshotDialog:onClose()
	ModHubScreenshotDialog:superClass().onClose(self)
end

function ModHubScreenshotDialog:setModInfo(modInfo)
	self.filenames = modInfo:getScreenshots()

	self.list:reloadData()
	self.headerText:setText(modInfo:getName())
end

function ModHubScreenshotDialog:getNumberOfItemsInSection(list, section)
	return #self.filenames
end

function ModHubScreenshotDialog:populateCellForItemInSection(list, section, index, cell)
	cell:getAttribute("image"):setImageFilename(self.filenames[index])
end

function ModHubScreenshotDialog:onListSelectionChanged(list, section, index)
	self:updateSelectors()
end

function ModHubScreenshotDialog:inputEvent(action, value, eventUsed)
	eventUsed = ModHubScreenshotDialog:superClass().inputEvent(self, action, value, eventUsed)

	if not eventUsed and (action == InputAction.MENU_PAGE_PREV or action == InputAction.MENU_PAGE_NEXT) then
		local curIndex = self.list.selectedIndex

		if action == InputAction.MENU_PAGE_PREV then
			self.list:setSelectedIndex(math.max(curIndex - 1, 1))
		else
			self.list:setSelectedIndex(curIndex + 1)
		end

		self:updateSelectors()

		eventUsed = true
	end

	return eventUsed
end

function ModHubScreenshotDialog:updateSelectors()
	self.selectorLeftGamepad:setVisible(self.list.selectedIndex ~= 1)
	self.selectorRightGamepad:setVisible(self.list.selectedIndex ~= #self.filenames)
end

function ModHubScreenshotDialog:onClickBack(forceBack, usedMenuButton)
	if not usedMenuButton then
		return self:close()
	else
		return true
	end
end
