ImeSimulator = {
	IS_INITIALIZED = false,
	IS_ACTIVE = false,
	LAST_STRING = "",
	IS_CLOSED = false,
	IS_CANCELED = false,
	MAX_CHARS = 0
}

function ImeSimulator.init()
	if ImeSimulator.IS_INITIALIZED then
		return
	end

	function imeIsSupported()
		Logging.devInfo("Reporting IME as available")

		return true
	end

	function imeAbort()
		Logging.devInfo("IME aborted")
		ImeSimulator.cancel()
	end

	function imeOpen(text, title, description, placeholder, keyboardType, maxCharacters)
		ImeSimulator.TITLE = title
		ImeSimulator.DESCRIPTION = description
		ImeSimulator.PLACEHOLDER = placeholder
		ImeSimulator.LAST_STRING = text
		ImeSimulator.MAX_CHARS = maxCharacters
		ImeSimulator.IS_ACTIVE = true

		return true
	end

	function imeIsComplete()
		return ImeSimulator.IS_CLOSED, ImeSimulator.IS_CANCELED
	end

	function imeGetLastString()
		return ImeSimulator.LAST_STRING
	end

	local oldUpdate = update

	function update(dt)
		oldUpdate(dt)

		ImeSimulator.IS_CLOSED = false
		ImeSimulator.IS_CANCELED = false
	end

	local oldDraw = draw

	function draw()
		oldDraw()

		if ImeSimulator.IS_ACTIVE then
			new2DLayer()
			drawFilledRect(0, 0, 1, 1, 0, 0, 0, 1)
			drawFilledRect(0.2, 0.2, 0.6, 0.6, 0.2, 0.2, 0.2, 0.9)
			setTextAlignment(RenderText.ALIGN_CENTER)
			renderText(0.5, 0.76, 0.025, "IME Simulator")
			renderText(0.5, 0.7, 0.025, "Title: " .. ImeSimulator.TITLE)
			renderText(0.5, 0.67, 0.025, "Desc: " .. ImeSimulator.DESCRIPTION)
			renderText(0.5, 0.64, 0.025, "Placeholder: " .. ImeSimulator.PLACEHOLDER)
			renderText(0.5, 0.58, 0.025, "Text: " .. ImeSimulator.LAST_STRING)
			setTextAlignment(RenderText.ALIGN_LEFT)
		end
	end

	local oldKeyEvent = keyEvent

	function keyEvent(unicode, sym, modifier, isDown)
		if ImeSimulator.IS_ACTIVE then
			if isDown then
				local len = utf8Strlen(ImeSimulator.LAST_STRING)

				if sym == Input.KEY_return then
					ImeSimulator.close()

					return
				elseif sym == Input.KEY_esc then
					ImeSimulator.cancel()

					return
				elseif sym == Input.KEY_backspace then
					if len > 0 then
						ImeSimulator.LAST_STRING = utf8Substr(ImeSimulator.LAST_STRING, 0, len - 1)
					end

					return
				end

				if getCanRenderUnicode(unicode) and (ImeSimulator.MAX_CHARS == 0 or len < ImeSimulator.MAX_CHARS) then
					ImeSimulator.LAST_STRING = ImeSimulator.LAST_STRING .. unicodeToUtf8(unicode)
				end
			end
		else
			oldKeyEvent(unicode, sym, modifier, isDown)
		end
	end

	ImeSimulator.IS_INITIALIZED = true

	print([[


  ##################   Warning: IME Simulator active!   ##################

]])
end

function ImeSimulator.close()
	ImeSimulator.IS_CLOSED = true
	ImeSimulator.IS_CANCELED = false
	ImeSimulator.IS_ACTIVE = false
end

function ImeSimulator.cancel()
	ImeSimulator.IS_CLOSED = true
	ImeSimulator.IS_CANCELED = true
	ImeSimulator.IS_ACTIVE = false
end
