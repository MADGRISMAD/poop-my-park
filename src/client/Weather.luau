-- Efectos de clima en el cliente: cielo, lluvia, nieve, arcoíris, rayos y meteoritos.
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Data = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"))
local UI = require(script.Parent.UI)
local Juice = require(script.Parent.Juice)

local M = {}
local cam = workspace.CurrentCamera
local fx = UI.new("Folder", { Name = "Clima" }, workspace)
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or UI.new("Atmosphere", { Density = 0.25, Haze = 0 }, Lighting)

-- cielo por clima
local SKY = {
	[""] = { ClockTime = 14, Brightness = 2, Ambient = Color3.fromRGB(110, 110, 120), density = 0.25, color = Color3.fromRGB(199, 199, 199) },
	lluvia = { ClockTime = 15, Brightness = 0.8, Ambient = Color3.fromRGB(80, 90, 110), density = 0.45, color = Color3.fromRGB(140, 150, 170) },
	tormenta = { ClockTime = 17.5, Brightness = 0.4, Ambient = Color3.fromRGB(60, 60, 85), density = 0.55, color = Color3.fromRGB(90, 90, 120) },
	nevada = { ClockTime = 13, Brightness = 1.6, Ambient = Color3.fromRGB(150, 160, 185), density = 0.5, color = Color3.fromRGB(230, 235, 255) },
	arcoiris = { ClockTime = 13, Brightness = 3, Ambient = Color3.fromRGB(150, 140, 160), density = 0.15, color = Color3.fromRGB(255, 230, 245) },
	meteoritos = { ClockTime = 0, Brightness = 1, Ambient = Color3.fromRGB(70, 60, 120), density = 0.3, color = Color3.fromRGB(120, 90, 200) },
}

-- emisor que sigue a la cámara (lluvia / nieve)
local cloud = UI.new("Part", { Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(160, 1, 160) }, fx)
local rain = UI.new("ParticleEmitter", {
	Texture = "rbxasset://textures/particles/sparkles_main.dds", EmissionDirection = Enum.NormalId.Bottom, Enabled = false,
	Rate = 900, Lifetime = NumberRange.new(1, 1.2), Speed = NumberRange.new(80, 95), Size = NumberSequence.new(0.18),
	Squash = NumberSequence.new(3), Color = ColorSequence.new(Color3.fromRGB(170, 200, 255)), Transparency = NumberSequence.new(0.35),
	Orientation = Enum.ParticleOrientation.VelocityParallel, LightEmission = 0.2,
}, cloud)
local snow = UI.new("ParticleEmitter", {
	Texture = "rbxasset://textures/particles/sparkles_main.dds", EmissionDirection = Enum.NormalId.Bottom, Enabled = false,
	Rate = 350, Lifetime = NumberRange.new(6, 8), Speed = NumberRange.new(7, 12), Size = NumberSequence.new(0.4),
	SpreadAngle = Vector2.new(25, 25), Acceleration = Vector3.new(2, 0, 1), Color = ColorSequence.new(Color3.new(1, 1, 1)),
	RotSpeed = NumberRange.new(-90, 90),
}, cloud)
RunService.RenderStepped:Connect(function()
	cloud.CFrame = CFrame.new(cam.CFrame.Position + Vector3.new(0, 45, 0))
end)

-- arcoíris: 7 bandas hechas con Beams curvos sobre la cámara
local rainbow = {}
local function showRainbow(on)
	for _, b in rainbow do b:Destroy() end
	rainbow = {}
	if not on then return end
	local c = cam.CFrame.Position
	local look = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z).Unit
	local side = look:Cross(Vector3.yAxis)
	local base = c + look * 260
	for i = 0, 6 do
		local holder = UI.new("Part", { Anchored = true, CanCollide = false, Transparency = 1, Size = Vector3.one, Position = base }, fx)
		local a0 = UI.new("Attachment", { WorldPosition = base - side * (220 - i * 6) }, holder)
		local a1 = UI.new("Attachment", { WorldPosition = base + side * (220 - i * 6) }, holder)
		for _, at in { a0, a1 } do -- el eje hacia arriba hace que la curva sea un arco
			at.Axis = Vector3.yAxis
			at.SecondaryAxis = side
		end
		UI.new("Beam", { Attachment0 = a0, Attachment1 = a1, Width0 = 7, Width1 = 7, CurveSize0 = 290 - i * 8, CurveSize1 = -(290 - i * 8),
			Color = ColorSequence.new(Color3.fromHSV(i / 7, 0.75, 1)), Transparency = NumberSequence.new(0.35), LightEmission = 0.6, FaceCamera = true, Segments = 40 }, holder)
		table.insert(rainbow, holder)
	end
end

local current = nil
local function apply(id)
	if id == current then return end
	current = id
	local sky = SKY[id] or SKY[""]
	TweenService:Create(Lighting, TweenInfo.new(3), { ClockTime = sky.ClockTime, Brightness = sky.Brightness, Ambient = sky.Ambient }):Play()
	TweenService:Create(atmosphere, TweenInfo.new(3), { Density = sky.density, Color = sky.color }):Play()
	rain.Enabled = id == "lluvia" or id == "tormenta"
	snow.Enabled = id == "nevada"
	showRainbow(id == "arcoiris")
end
workspace:GetAttributeChangedSignal("Weather"):Connect(function() apply(workspace:GetAttribute("Weather") or "") end)
task.defer(apply, workspace:GetAttribute("Weather") or "")

-- rayo: zigzag de neón desde el cielo, destello y trueno
local function bolt(pos)
	local top = pos + Vector3.new(math.random(-20, 20), 140, math.random(-20, 20))
	local prev = top
	for i = 1, 9 do
		local nextP = top:Lerp(pos, i / 9) + (i < 9 and Vector3.new(math.random(-6, 6), 0, math.random(-6, 6)) or Vector3.zero)
		local len = (nextP - prev).Magnitude
		local seg = UI.new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 250, 180),
			Size = Vector3.new(0.6, 0.6, len), CFrame = CFrame.lookAt((prev + nextP) / 2, nextP) }, fx)
		Debris:AddItem(seg, 0.25)
		prev = nextP
	end
	local l = UI.new("Part", { Anchored = true, CanCollide = false, Transparency = 1, Position = pos + Vector3.new(0, 4, 0) }, fx)
	UI.new("PointLight", { Brightness = 8, Range = 60, Color = Color3.fromRGB(255, 250, 200) }, l)
	Debris:AddItem(l, 0.2)
	Juice.burst(pos + Vector3.new(0, 1, 0), Color3.fromRGB(255, 240, 100), 30)
	UI.sound("hatch", 0.5, 0.35)
	local d = (cam.CFrame.Position - pos).Magnitude
	if d < 120 then Juice.shake(0.6 * (1 - d / 120), 0.3) end
end

-- meteorito: bola encendida que cae y explota (el servidor aplica la mutación al impactar)
local function meteor(pos)
	local start = pos + Vector3.new(70, 160, 40)
	local ball = UI.new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Shape = Enum.PartType.Ball, Size = Vector3.one * 3,
		Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 140, 60), Position = start }, fx)
	UI.new("ParticleEmitter", { Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 80, Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(1, 3), Size = NumberSequence.new(2, 0), Color = ColorSequence.new(Color3.fromRGB(255, 180, 80), Color3.fromRGB(160, 90, 255)) }, ball)
	UI.new("PointLight", { Brightness = 3, Range = 30, Color = Color3.fromRGB(255, 160, 90) }, ball)
	local tw = TweenService:Create(ball, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = pos + Vector3.new(0, 1, 0) })
	tw:Play()
	tw.Completed:Connect(function()
		ball:Destroy()
		Juice.burst(pos + Vector3.new(0, 1, 0), Color3.fromRGB(190, 120, 255), 40)
		UI.sound("hatch", 0.8, 0.4)
		local d = (cam.CFrame.Position - pos).Magnitude
		if d < 100 then Juice.shake(0.7 * (1 - d / 100), 0.4) end
	end)
end

local function mutate(pos, id)
	local mu = Data.MUTATIONS[id]
	Juice.burst(pos + Vector3.new(0, 3, 0), mu.color, 35)
	Juice.floatText(pos + Vector3.new(0, 6, 0), `¡{string.upper(mu.name)}! {mu.icon}`, mu.color, true)
	UI.sound("gold", 1.4, 0.5)
end

-- pelea: nube de polvo con estrellas, como en las caricaturas
local function fight(pos)
	local p = UI.new("Part", { Anchored = true, CanCollide = false, CanQuery = false, Transparency = 1, Position = pos + Vector3.new(0, 2, 0) }, fx)
	UI.new("ParticleEmitter", { Texture = "rbxasset://textures/particles/smoke_main.dds", Rate = 40, Lifetime = NumberRange.new(0.6, 1),
		Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(3, 5),
		Color = ColorSequence.new(Color3.fromRGB(200, 185, 160)), Transparency = NumberSequence.new(0.3, 1) }, p)
	UI.new("ParticleEmitter", { Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 15, Lifetime = NumberRange.new(0.5, 0.8),
		Speed = NumberRange.new(6, 10), SpreadAngle = Vector2.new(180, 180), Size = NumberSequence.new(1, 0),
		Color = ColorSequence.new(Color3.fromRGB(255, 230, 80)) }, p)
	Debris:AddItem(p, Data.FIGHT.Duration)
	Juice.floatText(pos + Vector3.new(0, 6, 0), "💢 ¡PELEA!", Color3.fromRGB(255, 90, 90), true)
	UI.sound("gold", 0.6, 0.4)
end

ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fx").OnClientEvent:Connect(function(kind, pos, extra)
	if kind == "fight" then fight(pos)
	elseif kind == "bolt" then bolt(pos)
	elseif kind == "meteor" then meteor(pos)
	elseif kind == "mutate" then mutate(pos, extra) end
end)

return M
