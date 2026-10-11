-- Dibuja y anima los perros equipados de todos los jugadores: te siguen en formación
-- y corren hacia la popó o los platos cuando el servidor lo indica.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Data = require(Shared:WaitForChild("Data"))
local DogModel = require(Shared:WaitForChild("DogModel"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local M = {}
local folder = Instance.new("Folder")
folder.Name = "Mascotas"
folder.Parent = workspace
local owners = {} -- userId -> { dogId -> pet }

local function info(cfg)
	local m = cfg:GetAttribute("mutations")
	return { breed = cfg:GetAttribute("breed"), rarity = cfg:GetAttribute("rarity"), quality = cfg:GetAttribute("quality"),
		age = cfg:GetAttribute("age"), mutations = m and m ~= "" and string.split(m, ",") or {},
		size = cfg:GetAttribute("size"), fusion = cfg:GetAttribute("fusion") }
end

-- articulaciones animables del modelo (patas, cabeza, cola, orejas)
local ANIMATED = { Pata = true, Cabeza = true, Cola = true, Oreja = true }
local function rig(model)
	local joints = {}
	for _, p in model:GetChildren() do
		local w = p:IsA("BasePart") and ANIMATED[p.Name] and p:FindFirstChild("Joint")
		if w then
			table.insert(joints, { w = w, base = w.C0, kind = p.Name, x = w.C0.X, z = w.C0.Z, h = p.Size.Y / 2 })
		end
	end
	return joints
end

local function animate(pet, moving, sniff, dt)
	pet.walk = (pet.walk or 0) + dt * (moving and 14 or 0)
	local t = os.clock() + pet.id
	for _, j in pet.joints do
		if j.kind == "Pata" then -- paso diagonal, como un perro de verdad
			local phase = ((j.x > 0) == (j.z > 0)) and 0 or math.pi
			local a = moving and math.sin(pet.walk + phase) * 0.7 or 0
			j.w.C0 = j.base * CFrame.new(0, j.h, 0) * CFrame.Angles(a, 0, 0) * CFrame.new(0, -j.h, 0)
		elseif j.kind == "Cabeza" then
			local pitch = sniff and -0.45 + math.sin(t * 20) * 0.08 or math.sin(t * 1.3) * 0.05
			local yaw = moving and 0 or math.sin(t * 0.6) * 0.35
			j.w.C0 = j.base * CFrame.Angles(pitch, yaw, 0)
		elseif j.kind == "Cola" then
			j.w.C0 = j.base * CFrame.Angles(0, math.sin(t * (moving and 18 or 9)) * 0.6, 0)
		else -- orejas
			local flap = moving and math.sin(pet.walk * 2) * 0.25 or math.sin(t * 2) * 0.04
			j.w.C0 = j.base * CFrame.Angles(0, 0, flap * (j.x > 0 and 1 or -1))
		end
	end
end

-- globo de estado (🍖 hambre, 💢 peleado) sobre la cabeza
local function moodBubble(pet, cfg)
	local root = pet.model.PrimaryPart
	local g = Instance.new("BillboardGui")
	g.Name = "Animo"
	g.Size = UDim2.fromOffset(46, 46)
	g.StudsOffset = Vector3.new(0, 4 + 2 * pet.model:GetScale(), 0)
	g.MaxDistance = 70
	g.Parent = root
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.TextScaled = true
	t.Text = cfg:GetAttribute("mood") or ""
	t.Parent = g
	pet.bubble = t
end

local function addPet(uid, cfg)
	local pets = owners[uid]
	if not pets then
		pets = {}
		owners[uid] = pets
	end
	local pet = { id = tonumber(cfg.Name), t = math.random() * 10 }
	local x, z = cfg:GetAttribute("x"), cfg:GetAttribute("z")
	pet.pos = x and Vector3.new(x, 0, z) or nil
	pet.model = DogModel.new(info(cfg), Data.BREED[cfg:GetAttribute("breed")])
	pet.model.Parent = folder
	pet.joints = rig(pet.model)
	moodBubble(pet, cfg)
	pets[pet.id] = pet
	cfg.AttributeChanged:Connect(function(name) -- creció o mutó: reconstruir
		if pets[pet.id] ~= pet or name == "x" or name == "z" then return end
		if name == "mood" then
			pet.bubble.Text = cfg:GetAttribute("mood") or ""
			return
		end
		local cf = pet.model:GetPivot()
		pet.model:Destroy()
		pet.model = DogModel.new(info(cfg), Data.BREED[cfg:GetAttribute("breed")])
		pet.model:PivotTo(cf)
		pet.model.Parent = folder
		pet.joints = rig(pet.model)
		moodBubble(pet, cfg)
	end)
end

local function removeAll(uid)
	for _, p in owners[uid] or {} do
		p.model:Destroy()
		if p.carry then p.carry:Destroy() end
	end
	owners[uid] = nil
end

local function watch(f)
	local uid = tonumber(f.Name)
	for _, c in f:GetChildren() do addPet(uid, c) end
	f.ChildAdded:Connect(function(c) addPet(uid, c) end)
	f.ChildRemoved:Connect(function(c)
		local pets = owners[uid]
		local p = pets and pets[tonumber(c.Name)]
		if p then
			p.model:Destroy()
			if p.carry then p.carry:Destroy() end
			pets[p.id] = nil
		end
	end)
end

local root = ReplicatedStorage:WaitForChild("Pets")
for _, f in root:GetChildren() do watch(f) end
root.ChildAdded:Connect(watch)
root.ChildRemoved:Connect(function(f) removeAll(tonumber(f.Name)) end)

-- back > 0: tras recoger, el perro corre hasta su dueño con la popó en el hocico
Remotes:WaitForChild("PetTask").OnClientEvent:Connect(function(uid, dogId, pos, travel, stay, back)
	local pet = owners[uid] and owners[uid][dogId]
	if not pet then return end
	pet.pos = pet.pos or Vector3.new(pos.X, 0, pos.Z)
	pet.task = { from = pet.pos, to = Vector3.new(pos.X, 0, pos.Z), t0 = os.clock(), travel = travel, stay = stay, back = back }
end)

local function carryBall()
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * 0.9
	p.Color = Color3.fromRGB(95, 55, 25)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Parent = folder
	return p
end

RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	for uid, pets in owners do
		local owner = Players:GetPlayerByUserId(uid)
		local hrp = owner and owner.Character and owner.Character:FindFirstChild("HumanoidRootPart")
		for _, pet in pets do
			if pet.pos then
				local model = pet.model
				local s = model:GetScale()
				local prev = pet.pos
				local tk, sniff, carrying = pet.task, false, false
				if tk then
					local e = now - tk.t0
					if e < tk.travel then
						pet.pos = tk.from:Lerp(tk.to, e / tk.travel)
					elseif e < tk.travel + tk.stay then
						pet.pos, sniff = tk.to, true
						carrying = tk.back ~= nil and e > tk.travel + tk.stay * 0.6
					elseif tk.back and e < tk.travel + tk.stay + tk.back and hrp then
						local goal = Vector3.new(hrp.Position.X, 0, hrp.Position.Z)
						local d = tk.to - goal
						local a = (e - tk.travel - tk.stay) / tk.back
						pet.pos = tk.to:Lerp(goal + (d.Magnitude > 0.1 and d.Unit * 3 or Vector3.zero), a)
						carrying = true
					else
						pet.task = nil
					end
				end
				local vel = pet.pos - prev
				local moving = vel.Magnitude > 0.02
				pet.t += dt * (moving and 13 or 2)
				local y = 2.2 * s + (moving and math.abs(math.sin(pet.t)) * 0.4 * s or math.sin(pet.t) * 0.05 * s) - (sniff and 0.35 * s or 0)
				local p = Vector3.new(pet.pos.X, y, pet.pos.Z)
				local rot = model:GetPivot().Rotation
				if moving and not sniff then
					rot = rot:Lerp(CFrame.lookAt(p, p + Vector3.new(vel.X, 0, vel.Z).Unit).Rotation, math.min(1, dt * 10))
				end
				local cf = CFrame.new(p) * rot
				model:PivotTo(cf)
				animate(pet, moving, sniff, dt)
				if pet.bubble.Text ~= "" then pet.bubble.Rotation = math.sin(now * 4 + pet.id) * 10 end
				if carrying then
					pet.carry = pet.carry or carryBall()
					pet.carry.CFrame = cf * CFrame.new(0, 0.7 * s, -3.7 * s)
				elseif pet.carry then
					pet.carry:Destroy()
					pet.carry = nil
				end
			end
		end
	end
end)

-- vista 3D de un perro para cartas y aperturas
function M.viewport(parent, dog, props)
	local vf = Instance.new("ViewportFrame")
	vf.BackgroundTransparency = 1
	vf.Ambient = Color3.fromRGB(200, 200, 200)
	vf.LightColor = Color3.new(1, 1, 1)
	vf.LightDirection = Vector3.new(-1, -1, -0.5)
	for k, v in props or {} do vf[k] = v end
	local model = DogModel.new(dog, Data.BREED[dog.breed])
	local s = model:GetScale()
	model:PivotTo(CFrame.new())
	model.Parent = vf
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	local center = Vector3.new(0, 0.2, -0.6) * s
	cam.CFrame = CFrame.lookAt(center + Vector3.new(-0.6, 0.35, -1).Unit * 10 * s, center)
	cam.Parent = vf
	vf.CurrentCamera = cam
	vf.Parent = parent
	return vf, model
end

return M
