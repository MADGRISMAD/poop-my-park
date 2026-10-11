-- Pantalla de inicio con parallax. Al pulsar JUGAR las capas se abren y la cámara baja hasta tu personaje.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UI = require(script.Parent.UI)
local Pets = require(script.Parent.Pets)
local C = UI.C

local M = {}

local function tween(o, t, props, style, dir)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

-- colina = óvalo enorme que asoma por abajo
local function hill(layer, x, y, w, h, color)
	local f = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), BackgroundColor3 = color, BorderSizePixel = 0 }, layer)
	UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f)
	UI.stroke(f, 4, UI.dark(color, 0.35), true)
	return f
end

local function cloud(layer, x, y, s)
	local c = UI.new("Frame", { Position = UDim2.fromScale(x, y), Size = UDim2.fromOffset(220 * s, 90 * s), BackgroundTransparency = 1 }, layer)
	for _, b in { { 0, 0.35, 0.45, 0.65 }, { 0.25, 0, 0.5, 1 }, { 0.6, 0.25, 0.4, 0.75 } } do
		local p = UI.new("Frame", { Position = UDim2.fromScale(b[1], b[2]), Size = UDim2.fromScale(b[3], b[4]), BackgroundColor3 = C.white, BorderSizePixel = 0 }, c)
		UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, p)
	end
	return c
end

function M.play(hudGui)
	local player = Players.LocalPlayer
	hudGui.Enabled = false
	local gui = UI.new("ScreenGui", { Name = "Inicio", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 100 }, player:WaitForChild("PlayerGui"))
	local root = UI.new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(120, 200, 255), BorderSizePixel = 0 }, gui)
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(90, 170, 255), Color3.fromRGB(200, 235, 255)) }, root)

	-- capas de atrás hacia adelante; depth = cuánto se mueven con el parallax
	local layers = {}
	local function layer(depth)
		local l = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.2, 1.2), BackgroundTransparency = 1 }, root)
		table.insert(layers, { frame = l, depth = depth })
		return l
	end

	local sky = layer(0.1)
	local sun = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.78, 0.22), Size = UDim2.fromOffset(150, 150), BackgroundColor3 = Color3.fromRGB(255, 225, 90), BorderSizePixel = 0 }, sky)
	UI.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, sun)
	UI.new("UIStroke", { Thickness = 18, Color = Color3.fromRGB(255, 240, 160), Transparency = 0.4 }, sun)
	local clouds = layer(0.25)
	local cloudList = { cloud(clouds, 0.05, 0.12, 1), cloud(clouds, 0.42, 0.06, 0.7), cloud(clouds, 0.62, 0.3, 0.9), cloud(clouds, 0.22, 0.33, 0.6) }
	local far = layer(0.4)
	hill(far, 0.2, 0.55, 0.7, 0.9, Color3.fromRGB(90, 160, 90))
	hill(far, 0.75, 0.5, 0.8, 1, Color3.fromRGB(80, 150, 85))
	local mid = layer(0.7)
	hill(mid, 0.05, 0.66, 0.6, 0.8, Color3.fromRGB(110, 195, 95))
	hill(mid, 0.6, 0.62, 0.9, 0.9, Color3.fromRGB(120, 205, 100))
	-- cerca de madera
	for i = 0, 22 do
		local post = UI.new("Frame", { Position = UDim2.new(i / 22, 0, 0.7, 0), Size = UDim2.fromOffset(14, 70), BackgroundColor3 = Color3.fromRGB(150, 100, 55), BorderSizePixel = 0 }, mid)
		UI.stroke(post, 3, C.ink, true)
	end
	for _, y in { 0.72, 0.75 } do
		local rail = UI.new("Frame", { Position = UDim2.fromScale(0, y), Size = UDim2.new(1, 0, 0, 10), BackgroundColor3 = Color3.fromRGB(170, 115, 60), BorderSizePixel = 0 }, mid)
		UI.stroke(rail, 3, C.ink, true)
	end
	local front = layer(1)
	local ground = UI.new("Frame", { Position = UDim2.fromScale(-0.1, 0.78), Size = UDim2.fromScale(1.2, 0.4), BackgroundColor3 = Color3.fromRGB(95, 185, 75), BorderSizePixel = 0 }, front)
	UI.stroke(ground, 4, UI.dark(Color3.fromRGB(95, 185, 75), 0.4), true)

	-- perros reales en 3D al frente
	local dogs = {}
	for i, d in { { "callejero", "comun", "verde" }, { "husky", "raro", "azul" }, { "aurodog", "legend", "dorado" }, { "corgi", "comun", "gris" } } do
		local vf, model = Pets.viewport(front, { breed = d[1], rarity = d[2], quality = d[3], age = "adult", mutations = {} }, {
			AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(({ 0.2, 0.4, 0.62, 0.82 })[i], 0.9), Size = UDim2.fromOffset(240, 240) })
		model:PivotTo(CFrame.Angles(0, ({ 0.5, -0.4, 0.2, -0.7 })[i], 0))
		table.insert(dogs, { vf = vf, phase = i * 1.3 })
	end
	local poops = {}
	for i = 1, 6 do
		table.insert(poops, UI.text(front, { Text = "💩", Position = UDim2.fromScale(0.08 + i * 0.13, 0.86), Size = UDim2.fromOffset(46, 46) }, 0))
	end

	-- logo y botón (fijos, no hacen parallax)
	local logo = UI.text(root, { Text = "POOP MY PARK", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.24), Size = UDim2.fromScale(0.7, 0.2), TextColor3 = C.white, Rotation = -3 }, 6)
	UI.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 240, 120), Color3.fromRGB(255, 150, 40)) }, logo)
	local sub = UI.text(root, { Text = "💩 ¡Cuida perros, junta popó y descubre mutaciones! 🌈", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromScale(0.6, 0.06) }, 3)
	local play = UI.button(root, "JUGAR", C.green, function() end, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(300, 92) })
	UI.pop(logo, 0.3)

	-- parallax con el mouse (o balanceo suave en celular) + animación ambiente
	local t, target = 0, Vector2.zero
	local smooth = Vector2.zero
	local conn = RunService.RenderStepped:Connect(function(dt)
		t += dt
		local mouse = UserInputService:GetMouseLocation()
		local view = workspace.CurrentCamera.ViewportSize
		if UserInputService.MouseEnabled then
			target = Vector2.new(mouse.X / view.X - 0.5, mouse.Y / view.Y - 0.5) * 2
		else
			target = Vector2.new(math.sin(t * 0.4), math.cos(t * 0.3) * 0.5)
		end
		smooth = smooth:Lerp(target, math.min(1, dt * 4))
		for _, l in layers do
			l.frame.Position = UDim2.new(0.5, -smooth.X * 60 * l.depth, 0.5, -smooth.Y * 30 * l.depth)
		end
		for i, c in cloudList do
			local x = (c.Position.X.Scale + dt * 0.01 * (i % 2 + 1)) % 1.1
			c.Position = UDim2.fromScale(x, c.Position.Y.Scale)
		end
		for _, d in dogs do
			d.vf.Rotation = math.sin(t * 2 + d.phase) * 3
		end
		for i, p in poops do
			p.Rotation = math.sin(t * 3 + i) * 12
		end
		logo.Rotation = -3 + math.sin(t * 1.5) * 2
		local pulse = 1 + math.sin(t * 4) * 0.04
		play.Size = UDim2.fromOffset(300 * pulse, 92 * pulse)
	end)

	play.Activated:Wait()
	UI.sound("hatch", 1.3, 0.4)

	-- salida: el logo se va, las capas se abren como si entraras a la escena
	tween(logo, 0.4, { Position = UDim2.fromScale(0.5, -0.2) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
	tween(sub, 0.3, { TextTransparency = 1 })
	play.Visible = false
	conn:Disconnect()
	for _, l in layers do
		local push = l.depth ^ 2
		tween(l.frame, 1.1, { Position = UDim2.fromScale(0.5, 0.5 + push * 0.9), Size = UDim2.fromScale(1.2 + push * 1.5, 1.2 + push * 1.5) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end

	-- la cámara arranca alta sobre el parque y baja hasta el personaje
	local char = player.Character or player.CharacterAdded:Wait()
	local hrp = char:WaitForChild("HumanoidRootPart")
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local endCF = CFrame.lookAt(hrp.Position + Vector3.new(0, 10, -18), hrp.Position)
	cam.CFrame = CFrame.lookAt(hrp.Position + Vector3.new(0, 140, 120), hrp.Position + Vector3.new(0, 0, 60))
	task.wait(0.5)
	tween(root, 0.8, { GroupTransparency = 1 })
	tween(cam, 2.2, { CFrame = endCF }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut).Completed:Wait()
	cam.CameraType = Enum.CameraType.Custom
	gui:Destroy()
	hudGui.Enabled = true
end

return M
