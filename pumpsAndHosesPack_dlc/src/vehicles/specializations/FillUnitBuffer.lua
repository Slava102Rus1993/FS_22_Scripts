FillUnitBuffer = {
	MOD_DIRECTORY = g_currentModDirectory,
	MOD_NAME = g_currentModName,
	FILLUNIT_BUFFER_XML_KEY = "vehicle.fillUnitBuffer",
	prerequisitesPresent = function (specializations)
		return SpecializationUtil.hasSpecialization(FillUnit, specializations)
	end
}

function FillUnitBuffer.initSpecialization()
	local schema = Vehicle.xmlSchema

	schema:setXMLSpecializationType("FillUnitBuffer")
	schema:register(XMLValueType.FLOAT, FillUnitBuffer.FILLUNIT_BUFFER_XML_KEY .. ".buffer#fillUnitIndex", "Buffer FillUnit index")
	schema:setXMLSpecializationType()
end

function FillUnitBuffer.registerFunctions(vehicleType)
	SpecializationUtil.registerFunction(vehicleType, "getFillUnitBuffer", FillUnitBuffer.getFillUnitBuffer)
end

function FillUnitBuffer.registerEventListeners(vehicleType)
	SpecializationUtil.registerEventListener(vehicleType, "onLoad", FillUnitBuffer)
end

function FillUnitBuffer:onLoad(savegame)
	self.spec_fillUnitBuffer = self[("spec_%s.fillUnitBuffer"):format(FillUnitBuffer.MOD_NAME)]
	local spec = self.spec_fillUnitBuffer
	spec.bufferFillUnitIndex = self.xmlFile:getValue(FillUnitBuffer.FILLUNIT_BUFFER_XML_KEY .. ".buffer#fillUnitIndex", nil)
end

function FillUnitBuffer:getFillUnitBuffer()
	return self.spec_fillUnitBuffer.bufferFillUnitIndex
end
