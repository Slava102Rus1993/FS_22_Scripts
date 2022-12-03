BitmapUtil = {
	FORMAT = {}
}
BitmapUtil.FORMAT.BITMAP = 0
BitmapUtil.FORMAT.GREYMAP = 1
BitmapUtil.FORMAT.PIXELMAP = 2
BitmapUtil.FORMAT_TO_PNM = {
	[BitmapUtil.FORMAT.BITMAP] = {
		extension = "pbm",
		getHeader = function (width, height, maxBrightness)
			return string.format("P4\n%d %d\n", width, height)
		end,
		getPixel = function (pixelTable)
			return string.format("%c", pixelTable[1])
		end
	},
	[BitmapUtil.FORMAT.GREYMAP] = {
		extension = "pgm",
		getHeader = function (width, height, maxBrightness)
			return string.format([[
P5
%d %d
%d
]], width, height, maxBrightness)
		end,
		getPixel = function (pixelTable)
			return string.format("%c", pixelTable[1])
		end
	},
	[BitmapUtil.FORMAT.PIXELMAP] = {
		extension = "ppm",
		getHeader = function (width, height, maxBrightness)
			return string.format([[
P6
%d %d
%d
]], width, height, maxBrightness)
		end,
		getPixel = function (pixelTable)
			return string.format("%c%c%c", pixelTable[1], pixelTable[2], pixelTable[3])
		end
	}
}

function BitmapUtil.writeBitmapToFile(pixels, width, height, filepath, imageFormat)
	local maxBrightness = 255
	local pnmFormat = BitmapUtil.FORMAT_TO_PNM[imageFormat]

	if pnmFormat == nil then
		Logging.error("Invalid image format '%s'. Use one of BitmapUtil.FORMAT", imageFormat)

		return false
	end

	filepath = string.format("%s.%s", filepath, pnmFormat.extension or "pnm")
	local file = createFile(filepath, FileAccess.WRITE)

	if file == 0 then
		Logging.error("BitmapUtil.writeBitmapToFile(): Unable to create file '%s'", filepath)

		return false
	end

	fileWrite(file, pnmFormat.getHeader(width, height, maxBrightness))

	local pixelsToWrite = {}
	local concatFunc = table.concat
	local clearFunc = table.clear

	for pixelIndex = 1, #pixels do
		pixelsToWrite[#pixelsToWrite + 1] = pnmFormat.getPixel(pixels[pixelIndex])

		if pixelIndex % 1025 == 0 then
			fileWrite(file, concatFunc(pixelsToWrite))
			clearFunc(pixelsToWrite)
		end
	end

	if #pixelsToWrite > 0 then
		fileWrite(file, concatFunc(pixelsToWrite))
	end

	delete(file)
	Logging.info("Wrote bitmap (width=%d, height=%d) to '%s'", width, height, filepath)

	return true
end

function BitmapUtil.writeBitmapToFileFromIterator(iterator, width, height, filepath, imageFormat)
	local pnmFormat = BitmapUtil.FORMAT_TO_PNM[imageFormat]

	if pnmFormat == nil then
		Logging.error("Invalid image format '%s'. Use one of BitmapUtil.FORMAT", imageFormat)

		return false
	end

	filepath = string.format("%s.%s", filepath, pnmFormat.extension or "pnm")
	local file = createFile(filepath, FileAccess.WRITE)

	if file == 0 then
		Logging.error("BitmapUtil.writeBitmapToFileFromIterator(): Unable to create file '%s'", filepath)

		return false
	end

	local maxBrightness = 255

	fileWrite(file, pnmFormat.getHeader(width, height, maxBrightness))

	local pixelsToWrite = {}
	local pixelIndex = 1
	local concatFunc = table.concat
	local clearFunc = table.clear

	for pixel in iterator() do
		pixelsToWrite[#pixelsToWrite + 1] = pnmFormat.getPixel(pixel)

		if pixelIndex % 1025 == 0 then
			fileWrite(file, concatFunc(pixelsToWrite))
			clearFunc(pixelsToWrite)
		end

		pixelIndex = pixelIndex + 1
	end

	if #pixelsToWrite > 0 then
		fileWrite(file, concatFunc(pixelsToWrite))
	end

	delete(file)
	Logging.info("Wrote bitmap (width=%d, height=%d) to '%s'", width, height, filepath)

	return true
end
