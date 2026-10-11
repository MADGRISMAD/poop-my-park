local Data = require(script.Parent.Data)

local BLACK = Color3.fromRGB(25, 25, 25)
local function D_icons(list)
	local s = Data.mutationIcons(list)
	return s ~= "" and s .. " " or ""
end
local M = {}

-- Construye el perro a escala 1 (mira hacia -Z) y lo escala con ScaleTo.
-- El cuerpo es la raíz anclada; todo lo demás va soldado a él.
function M.new(dog, breed)
	local rarity = Data.RARITY[dog.rarity]
	local quality = Data.QUALITY[dog.quality]
	local rIdx = Data.RARITY_IDX[dog.rarity]
	local body = breed.body
	local accent = breed.spot or body:Lerp(Color3.new(0, 0, 0), 0.25)
	local snoutC = body:Lerp(Color3.new(1, 1, 1), 0.45)
	local short = breed.id == "pug" or breed.id == "bulldog"

	local model = Instance.new("Model")
	model.Name = breed.name

	local root = Instance.new("Part")
	root.Name = "Cuerpo"
	root.Size = Vector3.new(2, 1.6, 3.2)
	root.Color = body
	root.Material = Enum.Material.SmoothPlastic
	root.Anchored = true
	root.CanCollide = false
	root.Parent = model
	model.PrimaryPart = root

	-- cada pieza va unida con un Weld a su "padre" (cuerpo, cabeza o pata) para poder animarla
	local function add(name, size, off, color, shape, rot, material, to)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		if shape then p.Shape = shape end
		p.CFrame = root.CFrame * CFrame.new(off) * (rot or CFrame.new())
		local parent = to or root
		local w = Instance.new("Weld")
		w.Name = "Joint"
		w.Part0, w.Part1 = parent, p
		w.C0 = parent.CFrame:ToObjectSpace(p.CFrame)
		w.Parent = p
		p.Parent = model
		return p
	end
	local BALL, NEON = Enum.PartType.Ball, Enum.Material.Neon

	local head = add("Cabeza", Vector3.new(1.7, 1.5, 1.6), Vector3.new(0, 1.1, -2), body)
	if short then
		add("Hocico", Vector3.new(1, 0.6, 0.5), Vector3.new(0, 0.8, -2.9), snoutC, nil, nil, nil, head)
		add("Nariz", Vector3.one * 0.4, Vector3.new(0, 1.0, -3.2), BLACK, BALL, nil, nil, head)
	else
		add("Hocico", Vector3.new(0.9, 0.7, 1), Vector3.new(0, 0.8, -3), snoutC, nil, nil, nil, head)
		add("Nariz", Vector3.one * 0.4, Vector3.new(0, 1.1, -3.5), BLACK, BALL, nil, nil, head)
	end
	for _, x in { -0.5, 0.5 } do
		add("Ojo", Vector3.one * 0.3, Vector3.new(x, 1.5, -2.78), BLACK, BALL, nil, nil, head)
		if breed.ears == "floppy" then
			add("Oreja", Vector3.new(0.4, 1.1, 0.7), Vector3.new(x * 1.9, 1.3, -1.9), accent, nil, CFrame.Angles(0, 0, x * 0.5), nil, head)
		else
			add("Oreja", Vector3.new(0.5, 1, 0.5), Vector3.new(x * 1.8, 1.9, -1.8), accent, nil, CFrame.Angles(0, 0, -x * 0.6), nil, head)
		end
	end
	add("Collar", Vector3.new(1.8, 0.35, 1.7), Vector3.new(0, 0.45, -1.5), rarity.color, nil, nil, nil, head)
	add("Cola", Vector3.new(0.45, 0.45, 1.5), Vector3.new(0, 1, 2.2), accent, nil, CFrame.Angles(-0.7, 0, 0))
	for _, x in { -0.65, 0.65 } do
		for _, z in { -1.1, 1.1 } do
			local leg = add("Pata", Vector3.new(0.6, 1.4, 0.6), Vector3.new(x, -1.5, z), body)
			add("Garra", Vector3.new(0.7, 0.3, 0.7), Vector3.new(x, -2.05, z), snoutC, nil, nil, nil, leg)
		end
	end
	if breed.spot then
		for _, o in { Vector3.new(0.5, 0.86, -0.6), Vector3.new(-0.5, 0.86, 0.5), Vector3.new(0.3, 0.86, 1.1) } do
			add("Mancha", Vector3.new(0.6, 0.12, 0.6), o, breed.spot)
		end
	end

	-- detalles especiales
	if breed.id == "aurodog" then
		for _, x in { -0.5, 0, 0.5 } do
			add("Corona", Vector3.new(0.3, x == 0 and 0.7 or 0.5, 0.3), Vector3.new(x, 2.1, -2), Color3.fromRGB(255, 215, 0), nil, nil, NEON, head)
		end
	elseif breed.id == "mecanico" then
		add("Visor", Vector3.new(1.5, 0.35, 0.2), Vector3.new(0, 1.5, -2.85), Color3.fromRGB(80, 240, 255), nil, nil, NEON, head)
	end
	if rIdx >= 4 then
		local light = Instance.new("PointLight")
		light.Color = rarity.color
		light.Range = 12
		light.Parent = root
		local fx = Instance.new("ParticleEmitter")
		fx.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		fx.Color = ColorSequence.new(rarity.color)
		fx.Rate = rIdx >= 6 and 14 or 7
		fx.Lifetime = NumberRange.new(1)
		fx.Speed = NumberRange.new(2, 4)
		fx.Parent = root
	end

	-- fusión: cada nivel añade un detalle (estrella, cuernos, alas, aureola, aura de fuego)
	local f = dog.fusion or 0
	local fc = rarity.color
	if f >= 1 then
		add("Estrella", Vector3.one * 0.5, Vector3.new(0, 0.3, -2.4), Color3.fromRGB(255, 220, 60), BALL, nil, NEON, head)
	end
	if f >= 2 then
		for _, x in { -0.45, 0.45 } do
			add("Cuerno", Vector3.new(0.3, 0.9, 0.3), Vector3.new(x, 2.1, -2.3), fc, nil, CFrame.Angles(-0.3, 0, -x * 0.6), NEON, head)
		end
	end
	if f >= 3 then
		for _, x in { -1, 1 } do
			local wing = add("Ala", Vector3.new(2.6, 0.15, 1.4), Vector3.new(x * 1.9, 1.1, -0.2), Color3.new(1, 1, 1), nil, CFrame.Angles(0, 0, x * 0.5), NEON)
			wing.Transparency = 0.25
		end
	end
	if f >= 4 then
		local halo = add("Halo", Vector3.new(0.15, 1.6, 1.6), Vector3.new(0, 2.7, -2), Color3.fromRGB(255, 240, 150), Enum.PartType.Cylinder, CFrame.Angles(0, 0, math.pi / 2), NEON, head)
		halo.Transparency = 0.2
	end
	if f >= 5 then
		local fire = Instance.new("Fire")
		fire.Color, fire.SecondaryColor, fire.Size, fire.Heat = fc, Color3.fromRGB(255, 220, 120), 6, 4
		fire.Parent = root
	end

	-- mutaciones: cambian el material/color y añaden partículas
	local muts = dog.mutations or {}
	local KEEP = { Ojo = true, Nariz = true, Collar = true, Corona = true, Visor = true, Estrella = true, Cuerno = true, Ala = true, Halo = true }
	local function paint(color, amount, material)
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") and not KEEP[p.Name] then
				p.Color = p.Color:Lerp(color, amount)
				if material then p.Material = material end
			end
		end
	end
	local function emit(color, rate, speed, size, accel)
		local fx = Instance.new("ParticleEmitter")
		fx.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		fx.Color = typeof(color) == "ColorSequence" and color or ColorSequence.new(color)
		fx.Rate = rate
		fx.Lifetime = NumberRange.new(0.6, 1.2)
		fx.Speed = NumberRange.new(speed[1], speed[2])
		fx.Size = NumberSequence.new(size, 0)
		fx.SpreadAngle = Vector2.new(180, 180)
		fx.Acceleration = accel or Vector3.zero
		fx.Parent = root
	end
	local has = function(id) return table.find(muts, id) ~= nil end
	if has("dorado") then paint(Color3.fromRGB(255, 200, 40), 0.85, Enum.Material.Foil) end
	if has("cosmico") then
		paint(Color3.fromRGB(90, 40, 170), 0.6, Enum.Material.Neon)
		emit(Color3.fromRGB(200, 160, 255), 10, { 1, 3 }, 0.5)
	end
	if has("helado") then
		paint(Color3.fromRGB(150, 210, 255), 0.7, Enum.Material.Ice)
		emit(Color3.new(1, 1, 1), 6, { 1, 2 }, 0.4, Vector3.new(0, -4, 0))
	elseif has("congelado") then
		paint(Color3.fromRGB(180, 230, 255), 0.45, Enum.Material.Ice)
	end
	if has("mojado") then
		for _, p in model:GetChildren() do
			if p:IsA("BasePart") then p.Reflectance = 0.25 end
		end
		emit(Color3.fromRGB(90, 170, 255), 6, { 0, 1 }, 0.25, Vector3.new(0, -20, 0))
	end
	if has("electrificado") then
		emit(Color3.fromRGB(255, 240, 80), 25, { 6, 12 }, 0.35)
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 240, 120)
		l.Range = 10
		l.Parent = root
	end
	if has("arcoiris") then
		local seq = {}
		for i = 0, 6 do table.insert(seq, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV(i / 7, 0.8, 1))) end
		emit(ColorSequence.new(seq), 14, { 2, 5 }, 0.5)
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "Nombre"
	gui.Size = UDim2.fromOffset(200, 56)
	gui.MaxDistance = 45
	gui.Parent = root
	local function line(y, h, text, color)
		local l = Instance.new("TextLabel")
		l.Position = UDim2.fromScale(0, y)
		l.Size = UDim2.fromScale(1, h)
		l.BackgroundTransparency = 1
		l.TextScaled = true
		l.Font = Enum.Font.FredokaOne
		l.TextColor3 = color
		l.TextStrokeTransparency = 0
		l.Text = text
		l.Parent = gui
	end
	line(0, 0.6, D_icons(muts) .. breed.name .. (f > 0 and " " .. Data.FUSION.Stars[f] or ""), rarity.color)
	line(0.6, 0.4, quality.name, quality.color)

	M.setScale(model, breed.size * Data.DOG.AgeScale[dog.age] * (dog.size or 1))
	return model
end

function M.setScale(model, s)
	model:ScaleTo(s)
	model.PrimaryPart.Nombre.StudsOffset = Vector3.new(0, 1.8 + 1.6 * s, 0)
end

return M
