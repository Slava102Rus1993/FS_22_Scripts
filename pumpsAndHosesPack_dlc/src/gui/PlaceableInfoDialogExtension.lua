function PlaceableInfoDialog:updateRenameSandboxButton(placeable)
	if not self.createdRenameSandboxRoot then
		self.renameSandboxButton = self.renameButton:clone()
		self.renameSandboxButton.id = "renameSandboxButton"
		self.renameSandboxButton.inputActionName = "MENU_EXTRA_1"
		local _, iconSizeY = self.renameSandboxButton:getIconSize()

		self.renameSandboxButton:setPosition(0, self.renameSandboxButton.position[2] - 3 * iconSizeY)
		self.renameSandboxButton:setCallback("onClickCallback", "onClickSandboxRename")
		self.dialogElement:addElement(self.renameSandboxButton)

		self.createdRenameSandboxRoot = true
	end

	local canRename = placeable:getCanBeRenamedByFarm(g_currentMission:getFarmId())
	local canBuy = g_currentMission:getHasPlayerPermission(Farm.PERMISSION.BUY_PLACEABLE)
	local isSandboxPlaceable = placeable.isSandboxPlaceable ~= nil and placeable:isSandboxPlaceable()

	if self.renameSandboxButton ~= nil then
		self.renameSandboxButton:setVisible(isSandboxPlaceable)

		local isEnabled = canRename and canBuy and isSandboxPlaceable and placeable:isSandboxRoot()

		self.renameSandboxButton:setDisabled(not isEnabled)

		local text = g_i18n:getText("menu_rename_sandbox")

		self.renameSandboxButton:setText(text)
	end

	if self.renameButton ~= nil then
		self.renameButton:setCallback("onClickCallback", isSandboxPlaceable and "sandbox_onClickRename" or "onClickRename")
	end
end

function PlaceableInfoDialog:onClickSandboxRename()
	local text = g_i18n:getText("button_changeName")

	g_gui:showTextInputDialog({
		text = text,
		defaultText = self.placeable:getSandboxRootName(true),
		callback = function (result, yes)
			if yes then
				if result:len() == 0 then
					result = nil
				end

				self.placeable:setSandboxRootName(result)
				g_messageCenter:unsubscribe(SellPlaceableEvent, self)
				self:setPlaceable(self.placeable)
			end
		end,
		dialogPrompt = g_i18n:getText("ui_enterName"),
		imePrompt = g_i18n:getText("ui_enterName"),
		confirmText = g_i18n:getText("button_change")
	})
end

function PlaceableInfoDialog:sandbox_onClickRename()
	local text = g_i18n:getText("button_changeName")

	g_gui:showTextInputDialog({
		text = text,
		defaultText = self.placeable:getName(true),
		callback = function (result, yes)
			if yes then
				if result:len() == 0 then
					result = nil
				end

				self.placeable:setName(result)
				g_messageCenter:unsubscribe(SellPlaceableEvent, self)
				self:setPlaceable(self.placeable)
			end
		end,
		dialogPrompt = g_i18n:getText("ui_enterName"),
		imePrompt = g_i18n:getText("ui_enterName"),
		confirmText = g_i18n:getText("button_change")
	})
end
