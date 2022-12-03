Curve = class("Curve")
Curve.CATMULL = 1
Curve.BEZIER_CUBIC = 2
Curve.BEZIER_QUAD = 3
Curve.DRAW_STEPS = 20

function Curve:construct(type)
	type = type or Curve.CATMULL

	self:setType(type)
end

function Curve:setType(type)
	self.type = type
	self.pointFunction = Curve.CURVE_POINT[type]
end

function Curve:compute(t, p0, p1, p2, p3)
	return self:compute4p(t, p0, p1, p2, p3)
end

function Curve:compute4p(t, p0, p1, p2, p3)
	local x = self.pointFunction(t, p0[1], p1[1], p2[1], p3[1])
	local y = self.pointFunction(t, p0[2], p1[2], p2[2], p3[2])
	local z = self.pointFunction(t, p0[3], p1[3], p2[3], p3[3])

	return {
		x,
		y,
		z
	}
end

function Curve:compute3p(t, p0, p1, p2)
	local x = self.pointFunction(t, p0[1], p1[1], p2[1])
	local y = self.pointFunction(t, p0[2], p1[2], p2[2])
	local z = self.pointFunction(t, p0[3], p1[3], p2[3])

	return {
		x,
		y,
		z
	}
end

function Curve:draw(type, p0, p1, p2, p3)
	if type ~= self.type then
		self:setType(type or self.type)
	end

	local computeFunc = Curve.compute4p
	local color = {
		0,
		0,
		1,
		1
	}

	if type == Curve.BEZIER_CUBIC then
		color = {
			1,
			0,
			0,
			1
		}
	elseif type == Curve.BEZIER_QUAD then
		color = {
			0,
			1,
			0,
			1
		}
		computeFunc = Curve.compute3p
	end

	for i = 0, Curve.DRAW_STEPS do
		local t = i / Curve.DRAW_STEPS
		local point = computeFunc(self, t, p0, p1, p2, p3)

		drawDebugPoint(point[1], point[2], point[3], unpack(color))
	end

	drawDebugPoint(p0[1], p0[2], p0[3], 1, 0, 0, 1)
	drawDebugPoint(p1[1], p1[2], p1[3], 0, 1, 1, 1)
	drawDebugPoint(p2[1], p2[2], p2[3], 1, 1, 0, 1)

	if type ~= Curve.BEZIER_QUAD then
		drawDebugPoint(p3[1], p3[2], p3[3], 1, 0, 0, 1)
	end
end

function Curve:controlsFromQuadBezierToCubicBezier(p0, control, p3)
	local p1 = {
		Curve.quadBezierToCubicBezierControl(p0[1], control[1]),
		Curve.quadBezierToCubicBezierControl(p0[2], control[2]),
		Curve.quadBezierToCubicBezierControl(p0[3], control[3])
	}
	local p2 = {
		Curve.quadBezierToCubicBezierControl(p3[1], control[1]),
		Curve.quadBezierToCubicBezierControl(p3[2], control[2]),
		Curve.quadBezierToCubicBezierControl(p3[3], control[3])
	}

	return p0, p1, p2, p3
end

function Curve:controlsFromCubicBezierToCatmull(p0, p1, p2, p3)
	local x1, x2, x3, x4 = Curve.cubicBezierToCatmullPoint(p0[1], p1[1], p2[1], p3[1])
	local y1, y2, y3, y4 = Curve.cubicBezierToCatmullPoint(p0[2], p1[2], p2[2], p3[2])
	local z1, z2, z3, z4 = Curve.cubicBezierToCatmullPoint(p0[3], p1[3], p2[3], p3[3])
	local c0 = {
		x1,
		y1,
		z1
	}
	local c1 = {
		x2,
		y2,
		z2
	}
	local c2 = {
		x3,
		y3,
		z3
	}
	local c3 = {
		x4,
		y4,
		z4
	}

	return c0, c1, c2, c3
end

function Curve:controlsFromQuadBezierToCatmull(p0, control, p3)
	local c0, c1, c2, c3 = self:controlsFromQuadBezierToCubicBezier(p0, control, p3)

	return self:controlsFromCubicBezierToCatmull(c0, c1, c2, c3)
end

function Curve.quadBezierPoint(t, p0, p1, p2)
	return (1 - t)^2 * p0 + 2 * (1 - t) * t * p1 + t^2 * p2
end

function Curve.cubicBezierPoint(t, p0, p1, p2, p3)
	return (1 - t)^3 * p0 + 3 * (1 - t)^2 * t * p1 + 3 * (1 - t) * t^2 * p2 + t^3 * p3
end

function Curve.catmullRomPoint(t, p0, p1, p2, p3)
	return 0.5 * (2 * p1 + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t^2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t^3)
end

function Curve.catmullRomTensionPoint(t, p0, p1, p2, p3, tension)
	local a = p1
	local b = tension * (p2 - p0)
	local c = 3 * (p2 - p1) - tension * (p3 - p1) - 2 * tension * (p2 - p0)
	local d = -2 * (p2 - p1) + tension * (p3 - p1) + tension * (p2 - p0)

	return a + b * t + c * t^2 + d * t^3
end

function Curve.cubicBezierToCatmullPoint(p0, p1, p2, p3)
	return p3 + 6 * (p0 - p1), p0, p3, p0 + 6 * (p3 - p2)
end

function Curve.quadBezierToCubicBezierControl(point, control)
	return (point + 2 * control) / 3
end

Curve.CURVE_POINT = {
	[Curve.CATMULL] = Curve.catmullRomPoint,
	[Curve.BEZIER_CUBIC] = Curve.cubicBezierPoint,
	[Curve.BEZIER_QUAD] = Curve.quadBezierPoint
}
