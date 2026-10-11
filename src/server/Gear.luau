-- Tienda de equipo que se reabastece, equipo colocable en tu patio y sprays de mutación.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage.Shared.Data)
local State = require(script.Parent.State)
local Dogs = require(script.Parent.Dogs)

local rng = Random.new()
local M = {}
local stock, serial = {}, 0
local COST = {}
for _, it in Data.SHOP do COST[it.id] = it.cost end

local function restock()
	serial += 1
	stock = {}
	local rare = {}
	for _, it in Data.SHOP do
		if rng:NextNumber() < it.chance then
			stock[it.id] = rng:NextInteger(it.stock[1], it.stock[2])
			if it.chance <= 0.15 then table.insert(rare, Data.item(it.id).icon .. " " .. Data.item(it.id).name) end
		end
	end
	workspace:SetAttribute("RestockAt", os.time() + Data.RESTOCK)
	State.NotifyEv:FireAllClients("🛒 ¡La tienda de equipo se reabasteció!", "toast")
	if #rare > 0 then
		State.AnnounceEv:FireAllClients("¡En la tienda hay " .. table.concat(rare, ", ") .. "!", Color3.fromRGB(255, 170, 40))
	end
	for _, S in State.sessions do S.dirty = true end
end
task.spawn(function()
	while true do
		restock()
		task.wait(Data.RESTOCK)
	end
end)

-- lo que le queda a este jugador en el reabastecimiento actual
function M.stockFor(S)
	if S.serial ~= serial then S.serial, S.bought = serial, {} end
	local out = {}
	for id, n in stock do out[id] = n - (S.bought[id] or 0) end
	return out
end

function M.buy(S, id)
	local left = M.stockFor(S)[id] or 0
	if left <= 0 then return { ok = false, msg = "Agotado. Espera al reabastecimiento" } end
	if S.data.poop < COST[id] then return { ok = false, msg = "No te alcanza 💩" } end
	S.data.poop -= COST[id]
	S.bought[id] = (S.bought[id] or 0) + 1
	S.data.items[id] = (S.data.items[id] or 0) + 1
	S.dirty = true
	return { ok = true }
end

-- modelos de equipo -------------------------------------------------------------
local function part(model, size, cf, color, material, shape)
	local p = Instance.new("Part")
	p.Size, p.CFrame, p.Color = size, cf, color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide = true, false
	if shape then p.Shape = shape end
	p.Parent = model
	return p
end
local CYL = CFrame.Angles(0, 0, math.pi / 2)
local METAL = Color3.fromRGB(120, 125, 135)

local function build(id, pos)
	local def = Data.GEAR[id]
	local color = Data.MUTATIONS[def.mut].color
	local m = Instance.new("Model")
	m.Name = def.name
	local base = part(m, Vector3.new(0.6, 3, 3), CFrame.new(pos + Vector3.new(0, 0.3, 0)) * CYL, METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
	m.PrimaryPart = base
	local top
	if id == "aspersor" then
		part(m, Vector3.new(0.4, 3, 0.4), CFrame.new(pos + Vector3.new(0, 1.8, 0)), METAL, Enum.Material.Metal)
		top = part(m, Vector3.new(0.8, 1.6, 1.6), CFrame.new(pos + Vector3.new(0, 3.4, 0)) * CYL, color, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	elseif id == "pararrayos" then
		part(m, Vector3.new(0.4, 14, 0.4), CFrame.new(pos + Vector3.new(0, 7, 0)), METAL, Enum.Material.Metal)
		top = part(m, Vector3.one * 1.4, CFrame.new(pos + Vector3.new(0, 14.4, 0)), color, Enum.Material.Neon, Enum.PartType.Ball)
	elseif id == "congelador" then
		top = part(m, Vector3.new(4, 3, 3), CFrame.new(pos + Vector3.new(0, 2, 0)), color, Enum.Material.Ice)
		part(m, Vector3.new(3, 0.3, 2), CFrame.new(pos + Vector3.new(0, 3.6, 0)), Color3.new(1, 1, 1), Enum.Material.Neon)
	elseif id == "prisma" then
		part(m, Vector3.new(0.6, 2, 0.6), CFrame.new(pos + Vector3.new(0, 1.2, 0)), METAL, Enum.Material.Metal)
		top = part(m, Vector3.one * 2.2, CFrame.new(pos + Vector3.new(0, 3.6, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)), color, Enum.Material.Glass)
		top.Transparency = 0.2
	else -- antena
		part(m, Vector3.new(0.5, 5, 0.5), CFrame.new(pos + Vector3.new(0, 2.5, 0)), METAL, Enum.Material.Metal)
		part(m, Vector3.new(0.4, 5, 5), CFrame.new(pos + Vector3.new(0, 5.5, 0)) * CFrame.Angles(0, 0, math.rad(55)), METAL, Enum.Material.Metal, Enum.PartType.Cylinder)
		top = part(m, Vector3.one * 0.9, CFrame.new(pos + Vector3.new(-1.2, 6.6, 0)), color, Enum.Material.Neon, Enum.PartType.Ball)
	end
	local fx = Instance.new("ParticleEmitter")
	fx.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	fx.Color = ColorSequence.new(color)
	fx.Rate = 8
	fx.Lifetime = NumberRange.new(0.8, 1.4)
	fx.Speed = NumberRange.new(4, 9)
	fx.SpreadAngle = Vector2.new(60, 60)
	fx.Parent = top
	local light = Instance.new("PointLight")
	light.Color, light.Range = color, 10
	light.Parent = top
	-- círculo que muestra hasta dónde llega su efecto
	local ring = part(m, Vector3.new(0.05, def.radius * 2, def.radius * 2), CFrame.new(pos + Vector3.new(0, 0.25, 0)) * CYL, color, Enum.Material.Neon, Enum.PartType.Cylinder)
	ring.Transparency, ring.CanQuery = 0.85, false
	local gui = Instance.new("BillboardGui")
	gui.Size, gui.StudsOffset, gui.MaxDistance = UDim2.fromOffset(160, 30), Vector3.new(0, 4, 0), 50
	gui.Parent = top
	local l = Instance.new("TextLabel")
	l.Size, l.BackgroundTransparency, l.TextScaled = UDim2.fromScale(1, 1), 1, true
	l.FontFace = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
	l.TextColor3, l.TextStrokeTransparency = Color3.new(1, 1, 1), 0
	l.Text = def.icon .. " " .. def.name
	l.Parent = gui
	return m, l
end

local function saveList(S)
	S.data.gear = {}
	for _, g in S.gear do
		table.insert(S.data.gear, { id = g.id, x = g.pos.X - S.origin.X, z = g.pos.Z - S.origin.Z, expires = g.expires })
	end
	S.dirty = true
end

-- el equipo es temporal: se gasta cuando llega su hora
local function spawn(S, id, pos, expires)
	local model, label = build(id, pos)
	model.Parent = S.folder
	table.insert(S.gear, { id = id, pos = pos, model = model, label = label, expires = expires })
end

task.spawn(function()
	while true do
		task.wait(1)
		local now = os.time()
		for _, S in State.sessions do
			for i = #S.gear, 1, -1 do
				local g = S.gear[i]
				local def = Data.GEAR[g.id]
				local left = g.expires - now
				if left <= 0 then
					g.model:Destroy()
					table.remove(S.gear, i)
					saveList(S)
					State.notify(S, `{def.icon} Tu {def.name} se gastó`)
				else
					g.label.Text = string.format("%s %s %d:%02d", def.icon, def.name, left // 60, left % 60)
				end
			end
		end
	end
end)

function M.place(S, id)
	if not Data.GEAR[id] or (S.data.items[id] or 0) <= 0 then return { ok = false } end
	if #S.gear >= Data.MAX_GEAR then return { ok = false, msg = `Máximo {Data.MAX_GEAR} equipos colocados` } end
	local char = S.player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp or not Data.inYard(S.slot, hrp.Position, S.data.zones) then
		return { ok = false, msg = "Párate dentro de tu parque para colocarlo" }
	end
	S.data.items[id] -= 1
	spawn(S, id, Data.clampToYard(S.slot, hrp.Position, S.data.zones, 2), os.time() + Data.GEAR[id].dur)
	saveList(S)
	return { ok = true }
end

function M.restore(S)
	for _, g in S.data.gear do
		if Data.GEAR[g.id] and (g.expires or 0) > os.time() then
			spawn(S, g.id, Data.clampToYard(S.slot, S.origin + Vector3.new(g.x, 0, g.z), nil, 2), g.expires)
		end
	end
end

function M.useSpray(S, dogId, sprayId)
	local spray = Data.SPRAYS[sprayId]
	local dog = S.data.dogs[dogId]
	if not spray or not dog or (S.data.items[sprayId] or 0) <= 0 then return { ok = false } end
	if not Data.applyMutation(dog.mutations, spray.mut) then return { ok = false, msg = "Ese perro ya tiene esa mutación" } end
	S.data.items[sprayId] -= 1
	S.dirty = true
	if rng:NextNumber() < spray.chance then
		Dogs.mutate(S, dog, spray.mut)
		return { ok = true }
	end
	return { ok = false, msg = "El spray no funcionó esta vez 😢" }
end

return M
