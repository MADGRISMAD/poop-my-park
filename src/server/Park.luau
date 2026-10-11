-- Mapa estilo Grow a Garden: calle central con quioscos y 4 parques a cada lado.
-- Cada parque es el mismo cuadrado; al cambiar de tipo solo cambian el suelo y la decoración.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage.Shared.Data)

local c = Color3.fromRGB
local M = Enum.Material
local WOOD, DARK_WOOD, STONE = c(160, 110, 60), c(105, 70, 40), c(150, 150, 155)
local CYL = CFrame.Angles(0, 0, math.pi / 2) -- cilindros verticales
local H, ROAD = Data.YARD.Half, Data.YARD.Road
local LUCKIEST = Font.new("rbxasset://fonts/families/LuckiestGuy.json")

local folder = Instance.new("Folder")
folder.Name = "Parque"
folder.Parent = workspace

local function part(parent, name, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = typeof(cf) == "Vector3" and CFrame.new(cf) or cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.Anchored = true
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end
local function cyl(parent, name, h, d, pos, color, material)
	return part(parent, name, Vector3.new(h, d, d), CFrame.new(pos) * CYL, color, material, Enum.PartType.Cylinder)
end
local function ball(parent, name, d, pos, color, material)
	return part(parent, name, Vector3.one * d, pos, color, material, Enum.PartType.Ball)
end

local function label(p, text, face, color)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.Parent = p
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.FontFace = LUCKIEST
	t.TextColor3 = color
	t.Text = text
	t.Parent = g
	return t
end

local function light(p, range, color)
	local l = Instance.new("PointLight")
	l.Range = range
	l.Color = color or c(255, 220, 150)
	l.Parent = p
end

local function fence(parent, a, b)
	local d = b - a
	local len = d.Magnitude
	local look = CFrame.lookAt((a + b) / 2, b)
	for _, y in { 1.2, 2.4 } do
		part(parent, "Riel", Vector3.new(0.3, 0.3, len), look + Vector3.new(0, y, 0), WOOD, M.Wood)
	end
	local n = math.ceil(len / 8)
	for i = 0, n do
		part(parent, "Poste", Vector3.new(0.6, 3.2, 0.6), a + d * (i / n) + Vector3.new(0, 1.6, 0), DARK_WOOD, M.Wood)
	end
end

local function tree(parent, p)
	local h = 6
	part(parent, "Tronco", Vector3.new(1.6, h, 1.6), p + Vector3.new(0, h / 2, 0), c(110, 75, 40), M.Wood)
	ball(parent, "Copa", 9, p + Vector3.new(0, h + 3, 0), c(60, 150, 60), M.Grass)
	ball(parent, "Copa", 6, p + Vector3.new(1.5, h + 6.5, -1), c(80, 175, 70), M.Grass)
end

-- decoración por tipo de parque ------------------------------------------------------
-- R(x, z) = punto del patio (z positivo = al fondo, lejos de la calle)
local DECOR = {}
DECOR[1] = function(f, R)
	for _, xz in { { -30, 30 }, { 30, 30 }, { -32, -6 }, { 33, 4 } } do tree(f, R(xz[1], xz[2])) end
	cyl(f, "EstanqueBorde", 0.3, 17, R(-20, 26) + Vector3.new(0, 0.25, 0), STONE, M.Slate)
	cyl(f, "Estanque", 0.4, 15, R(-20, 26) + Vector3.new(0, 0.3, 0), c(60, 150, 220), M.Glass).Transparency = 0.3
	local house = R(22, 30)
	part(f, "CasaPerro", Vector3.new(6, 4, 6), house + Vector3.new(0, 2, 0), c(190, 70, 60), M.Wood)
	for _, side in { -1, 1 } do
		part(f, "TechoCasa", Vector3.new(6.6, 0.4, 4.2), CFrame.new(house + Vector3.new(0, 5, side * 1.5)) * CFrame.Angles(side * 0.55, 0, 0), c(90, 55, 40), M.Wood)
	end
	ball(f, "Pelota", 2, R(-8, -14) + Vector3.new(0, 1, 0), c(230, 50, 50))
end
DECOR[2] = function(f, R)
	for _, xz in { { -32, 30 }, { 32, 28 }, { -33, -10 }, { 33, -4 }, { 0, 34 } } do
		local p = R(xz[1], xz[2])
		part(f, "Tronco", Vector3.new(1.2, 9, 1.2), CFrame.new(p + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, 0, 0.12), c(150, 105, 60), M.Wood)
		for i = 0, 4 do
			part(f, "Hoja", Vector3.new(7, 0.4, 2), CFrame.new(p + Vector3.new(0.6, 9, 0)) * CFrame.Angles(0, i * math.pi * 2 / 5, -0.35) * CFrame.new(3, 0, 0), c(60, 170, 70), M.Grass)
		end
	end
	cyl(f, "Agua", 0.3, 24, R(-18, 22) + Vector3.new(0, 0.25, 0), c(60, 170, 230), M.Glass).Transparency = 0.25
	part(f, "Sombrilla", Vector3.new(0.4, 8, 0.4), R(20, 18) + Vector3.new(0, 4, 0), c(240, 240, 240))
	cyl(f, "Toldo", 1, 9, R(20, 18) + Vector3.new(0, 8, 0), c(240, 70, 90))
	part(f, "Toalla", Vector3.new(4, 0.1, 7), R(24, 10) + Vector3.new(0, 0.25, 0), c(60, 140, 255))
end
DECOR[3] = function(f, R)
	for _, xz in { { -32, 30 }, { 30, 32 }, { -33, -8 }, { 33, 0 }, { 8, 34 } } do
		local p = R(xz[1], xz[2])
		part(f, "Tronco", Vector3.new(1.2, 3, 1.2), p + Vector3.new(0, 1.5, 0), c(100, 70, 40), M.Wood)
		for i, d in { 8, 6, 4 } do
			cyl(f, "Pino", 2.6, d, p + Vector3.new(0, 2.5 + i * 2.2, 0), c(40, 110, 70), M.Grass)
			cyl(f, "NieveRama", 0.4, d * 0.8, p + Vector3.new(0, 3.9 + i * 2.2, 0), c(245, 250, 255), M.Snow)
		end
	end
	local sm = R(18, 16)
	for i, d in { 3.4, 2.5, 1.7 } do ball(f, "Muñeco", d, sm + Vector3.new(0, ({ 1.6, 4.3, 6.3 })[i], 0), c(250, 252, 255), M.Snow) end
	cyl(f, "Hielo", 0.3, 20, R(-16, 22) + Vector3.new(0, 0.25, 0), c(180, 225, 255), M.Ice)
end
DECOR[4] = function(f, R)
	for _, xz in { { -30, 30 }, { 28, 32 }, { -33, -6 }, { 33, 6 }, { 4, 32 } } do
		local p = R(xz[1], xz[2])
		local green = c(70, 140, 70)
		part(f, "Cactus", Vector3.new(2, 9, 2), p + Vector3.new(0, 4.5, 0), green, M.Grass)
		part(f, "Brazo", Vector3.new(3, 1.2, 1.2), p + Vector3.new(1.8, 4, 0), green, M.Grass)
		part(f, "Brazo", Vector3.new(1.2, 3, 1.2), p + Vector3.new(2.8, 5.5, 0), green, M.Grass)
		part(f, "Brazo", Vector3.new(2.6, 1.2, 1.2), p + Vector3.new(-1.6, 5.5, 0), green, M.Grass)
		part(f, "Brazo", Vector3.new(1.2, 2.6, 1.2), p + Vector3.new(-2.6, 6.6, 0), green, M.Grass)
	end
	for _, xz in { { -14, 20 }, { 16, 24 }, { 22, -20 } } do
		ball(f, "Roca", 4, R(xz[1], xz[2]) + Vector3.new(0, 1, 0), c(170, 120, 80), M.Sandstone)
	end
	local skull = R(-20, -22)
	ball(f, "Calavera", 2.4, skull + Vector3.new(0, 1, 0), c(245, 240, 225))
end
DECOR[5] = function(f, R)
	local v = R(0, 30)
	for i, d in { 24, 18, 12 } do
		cyl(f, "Volcan", 5, d, v + Vector3.new(0, 2.5 + (i - 1) * 5, 0), c(70, 50, 45), M.Basalt)
	end
	local crater = cyl(f, "Lava", 0.6, 9, v + Vector3.new(0, 15.2, 0), c(255, 110, 20), M.Neon)
	light(crater, 40, c(255, 120, 40))
	local smoke = Instance.new("Smoke")
	smoke.Color, smoke.Size, smoke.RiseVelocity, smoke.Opacity = c(60, 55, 55), 6, 10, 0.4
	smoke.Parent = crater
	for _, xz in { { -26, 10 }, { 24, 6 }, { -10, -24 } } do
		local lava = cyl(f, "Charco", 0.3, 9, R(xz[1], xz[2]) + Vector3.new(0, 0.25, 0), c(255, 90, 10), M.Neon)
		light(lava, 18, c(255, 110, 30))
	end
	for _, xz in { { -33, 30 }, { 33, -14 }, { 30, 30 } } do
		ball(f, "Roca", 4.5, R(xz[1], xz[2]) + Vector3.new(0, 1.2, 0), c(40, 35, 35), M.Basalt)
	end
end
DECOR[6] = function(f, R)
	for i, xz in { { -32, 30 }, { 32, 28 }, { -33, -8 }, { 33, 2 }, { 0, 34 } } do
		local p = R(xz[1], xz[2])
		if i % 2 == 1 then -- paleta
			part(f, "Palo", Vector3.new(0.6, 9, 0.6), p + Vector3.new(0, 4.5, 0), c(255, 255, 255))
			cyl(f, "Paleta", 1, 7, p + Vector3.new(0, 10, 0), Color3.fromHSV(i / 6, 0.6, 1), M.Neon).CFrame = CFrame.new(p + Vector3.new(0, 10, 0))
		else -- bastón de caramelo
			for k = 0, 5 do
				part(f, "Baston", Vector3.new(1.2, 1.4, 1.2), p + Vector3.new(0, 0.7 + k * 1.4, 0), k % 2 == 0 and c(235, 40, 60) or c(255, 255, 255))
			end
			part(f, "Gancho", Vector3.new(3, 1.2, 1.2), p + Vector3.new(1, 8.8, 0), c(235, 40, 60))
		end
	end
	for _, xz in { { -16, 20 }, { 14, 22 }, { 22, -18 }, { -24, -20 } } do
		ball(f, "Gomita", 3, R(xz[1], xz[2]) + Vector3.new(0, 1.2, 0), Color3.fromHSV(math.random(), 0.6, 1), M.Glass).Transparency = 0.15
	end
end
DECOR[7] = function(f, R)
	for _, xz in { { -28, 28 }, { 28, 26 }, { -30, -12 }, { 30, -8 }, { 0, 30 } } do
		cyl(f, "CraterBorde", 0.6, 10.5, R(xz[1], xz[2]) + Vector3.new(0, 0.1, 0), c(80, 70, 110), M.Slate)
		cyl(f, "Crater", 0.3, 9, R(xz[1], xz[2]) + Vector3.new(0, 0.25, 0), c(30, 25, 50), M.Slate)
	end
	local planet = ball(f, "Planeta", 12, R(0, 18) + Vector3.new(0, 26, 0), c(255, 120, 200), M.Neon)
	light(planet, 40)
	part(f, "Anillo", Vector3.new(0.4, 22, 22), CFrame.new(planet.Position) * CFrame.Angles(0.4, 0, math.pi / 2 + 0.3), c(255, 220, 120), M.Neon, Enum.PartType.Cylinder).Transparency = 0.3
	local rng = Random.new(7)
	for _ = 1, 30 do
		ball(f, "Estrella", 0.6, R(rng:NextNumber(-38, 38), rng:NextNumber(-38, 38)) + Vector3.new(0, 0.3, 0), c(255, 255, 200), M.Neon)
	end
end
DECOR[8] = function(f, R)
	for _, xz in { { -30, 30 }, { 30, 30 }, { -30, -20 }, { 30, -20 } } do
		local p = R(xz[1], xz[2])
		cyl(f, "Pilar", 12, 2.6, p + Vector3.new(0, 6, 0), c(255, 210, 90), M.Foil)
		ball(f, "Orbe", 2.4, p + Vector3.new(0, 13.4, 0), c(255, 255, 220), M.Neon)
	end
	for _, xz in { { -14, 24 }, { 12, 28 }, { 24, 4 }, { -24, 0 } } do
		local p = R(xz[1], xz[2]) + Vector3.new(0, 9, 0)
		for _, o in { Vector3.zero, Vector3.new(2.5, -0.5, 1), Vector3.new(-2.5, -0.5, -1) } do ball(f, "Nube", 5, p + o, c(255, 255, 255)) end
	end
	local halo = part(f, "Aureola", Vector3.new(0.6, 16, 16), CFrame.new(R(0, 20) + Vector3.new(0, 18, 0)) * CYL, c(255, 230, 120), M.Neon, Enum.PartType.Cylinder)
	halo.Transparency = 0.4
	light(halo, 50, c(255, 240, 180))
end

-- un parque: suelo + cerca + arco con cartel + carpeta de decoración --------------------
local function yard(slot)
	local side = Data.slotSide(slot)
	local C = Data.yardCenter(slot)
	local function R(x, z) return Data.yardRel(slot, x, z) end
	local y = Instance.new("Folder")
	y.Name = "Parcela" .. slot
	y.Parent = folder
	local floor = part(y, "Suelo", Vector3.new(H * 2, 0.2, H * 2), C + Vector3.new(0, 0.1, 0), Data.ZONES[1].color, Data.ZONES[1].material)
	local front, back = R(0, -H).Z, R(0, H).Z
	local x0, x1 = C.X - H, C.X + H
	local function V(x, z) return Vector3.new(x, 0, z) end
	fence(y, V(x0, front), V(C.X - 6, front))
	fence(y, V(C.X + 6, front), V(x1, front))
	fence(y, V(x0, front), V(x0, back))
	fence(y, V(x1, front), V(x1, back))
	fence(y, V(x0, back), V(x1, back))
	for _, x in { C.X - 6, C.X + 6 } do
		part(y, "PosteArco", Vector3.new(1, 7, 1), V(x, front) + Vector3.new(0, 3.5, 0), DARK_WOOD, M.Wood)
	end
	-- el cartel mira hacia la calle
	local sign = part(y, "Letrero", Vector3.new(14, 2.6, 0.8), CFrame.lookAt(V(C.X, front) + Vector3.new(0, 7.4, 0), V(C.X, front - side * 10) + Vector3.new(0, 7.4, 0)), WOOD, M.Wood)
	local text = label(sign, "PARQUE LIBRE", Enum.NormalId.Front, c(255, 240, 200))
	local decor = Instance.new("Folder")
	decor.Name = "Decoracion"
	decor.Parent = y
	DECOR[1](decor, R)
	return { floor = floor, sign = text, decor = decor, R = R }
end

-- construcción ----------------------------------------------------------------------
Lighting.ClockTime = 14
Lighting.Ambient = c(110, 110, 120)

local base = workspace:FindFirstChild("Baseplate")
if base then
	base.Size = Vector3.new(900, 20, 900)
	base.Color = c(95, 170, 75)
	base.Material = M.Grass
end

local X_MAX = 4 * 50 + 30
part(folder, "Calle", Vector3.new(X_MAX * 2, 0.22, ROAD * 2), Vector3.new(0, 0.11, 0), c(190, 175, 140), M.Cobblestone)
part(folder, "Linea", Vector3.new(X_MAX * 2, 0.24, 1), Vector3.new(0, 0.12, 0), c(240, 225, 180), M.SmoothPlastic)

local spawn = Instance.new("SpawnLocation")
spawn.Size = Vector3.new(8, 1, 8)
spawn.Position = Vector3.new(0, 0.6, 0)
spawn.Anchored, spawn.Neutral, spawn.Duration = true, true, 0
spawn.Color = c(255, 210, 90)
spawn.Material = M.SmoothPlastic
spawn.Parent = folder

-- quioscos en medio de la calle, mirando al punto de aparición
local function kiosk(pos, title, color, icon)
	local kcf = CFrame.lookAt(pos, Vector3.new(0, 0, pos.Z))
	part(folder, "Mostrador", Vector3.new(7, 3, 3), kcf * CFrame.new(0, 1.5, 0), WOOD, M.Wood)
	part(folder, "MostradorTope", Vector3.new(7.6, 0.3, 3.6), kcf * CFrame.new(0, 3.15, 0), c(210, 170, 110), M.Wood)
	for _, x in { -3.4, 3.4 } do
		for _, z in { -1.45, 1.45 } do
			part(folder, "PosteQuiosco", Vector3.new(0.4, 7, 0.4), kcf * CFrame.new(x, 3.5, z), DARK_WOOD, M.Wood)
		end
	end
	for i = 0, 5 do
		part(folder, "Toldo", Vector3.new(1.4, 0.5, 5), kcf * CFrame.new(-3.5 + i * 1.4, 7.25, 0), i % 2 == 0 and color or c(250, 250, 250))
	end
	label(part(folder, "Cartel", Vector3.new(6.4, 1.5, 0.3), kcf * CFrame.new(0, 6, -1.45), WOOD, M.Wood), title, Enum.NormalId.Front, c(255, 240, 200))
	local item = part(folder, "Producto", Vector3.new(1.8, 2.2, 0.5), kcf * CFrame.new(0, 4.4, -0.3), color, M.SmoothPlastic)
	label(item, icon, Enum.NormalId.Front, c(255, 255, 255))
	return item
end
local packKiosk = kiosk(Vector3.new(-14, 0, 0), "SOBRES", c(230, 70, 140), "?")
local gearKiosk = kiosk(Vector3.new(14, 0, 0), "EQUIPO", c(60, 150, 255), "🧰")

for x = -X_MAX + 10, X_MAX - 10, 40 do
	for _, z in { -ROAD + 1.5, ROAD - 1.5 } do
		part(folder, "Poste", Vector3.new(0.5, 9, 0.5), Vector3.new(x, 4.5, z), c(40, 40, 45), M.Metal)
		light(ball(folder, "Foco", 2, Vector3.new(x, 9.6, z), c(255, 230, 160), M.Neon), 28)
	end
end

-- tablero de líderes del servidor, mirando al punto de aparición
local board = part(folder, "Lideres", Vector3.new(16, 11, 0.6), CFrame.lookAt(Vector3.new(0, 6.5, -14), Vector3.new(0, 6.5, 0)), c(60, 40, 90), M.SmoothPlastic)
local boardText = label(board, "🏆 LÍDERES", Enum.NormalId.Front, c(255, 230, 140))
boardText.TextXAlignment = Enum.TextXAlignment.Left
boardText.TextYAlignment = Enum.TextYAlignment.Top
local pad = Instance.new("UIPadding")
pad.PaddingLeft, pad.PaddingTop, pad.PaddingRight, pad.PaddingBottom = UDim.new(0.05, 0), UDim.new(0.05, 0), UDim.new(0.05, 0), UDim.new(0.05, 0)
pad.Parent = boardText
for _, x in { -7.5, 7.5 } do
	part(folder, "PataTablero", Vector3.new(0.6, 6.5, 0.6), Vector3.new(x, 0.5, -14) + Vector3.new(0, 2.75, 0), DARK_WOOD, M.Wood)
end

local yards = {}
for slot = 1, Data.SLOTS do yards[slot] = yard(slot) end

-- árboles y flores fuera de los parques y la calle
local function blocked(x, z) return math.abs(x) < X_MAX + 10 and math.abs(z) < ROAD + H * 2 + 12 end
local rng = Random.new(42)
local trees = 0
while trees < 80 do
	local x, z = rng:NextInteger(-420, 420), rng:NextInteger(-300, 300)
	if not blocked(x, z) then
		tree(folder, Vector3.new(x, 0, z))
		trees += 1
	end
end
local colors = { c(255, 90, 120), c(255, 220, 60), c(250, 250, 250), c(180, 110, 255) }
local flowers = 0
while flowers < 220 do
	local x, z = rng:NextInteger(-400, 400), rng:NextInteger(-280, 280)
	if not blocked(x, z) then
		ball(folder, "Flor", 0.9, Vector3.new(x, 0.45, z), colors[rng:NextInteger(1, #colors)])
		flowers += 1
	end
end

local P = { pack = packKiosk, gear = gearKiosk }
function P.setBoard(text) boardText.Text = text end

-- cambia el tipo de parque de una parcela (mismo cuadrado, otro lugar)
function P.setPark(slot, kind, owner)
	local y = yards[slot]
	local z = Data.ZONES[kind]
	y.sign.Text = owner and `{z.icon} {string.upper(owner)}'S PARK` or "PARQUE LIBRE"
	if y.kind == kind then return end
	y.kind = kind
	y.floor.Color, y.floor.Material = z.color, z.material
	y.decor:ClearAllChildren()
	DECOR[kind](y.decor, y.R)
end

return P
