-- Estilo visual compartido: fuentes, colores y componentes "chunky" tipo simulador.
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"))

local M = {}
M.FONT = Font.new("rbxasset://fonts/families/LuckiestGuy.json")
M.BODY = Font.new("rbxasset://fonts/families/FredokaOne.json")
M.C = {
	ink = Color3.fromRGB(30, 20, 45), white = Color3.new(1, 1, 1),
	panel = Color3.fromRGB(255, 247, 228), panel2 = Color3.fromRGB(255, 226, 170),
	green = Color3.fromRGB(70, 205, 85), blue = Color3.fromRGB(60, 150, 255), gold = Color3.fromRGB(255, 190, 30),
	pink = Color3.fromRGB(255, 85, 170), purple = Color3.fromRGB(150, 90, 255), red = Color3.fromRGB(235, 65, 65),
	orange = Color3.fromRGB(255, 135, 35), grey = Color3.fromRGB(140, 140, 150), brown = Color3.fromRGB(140, 85, 45),
}

function M.new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
function M.corner(o, r) return M.new("UICorner", { CornerRadius = UDim.new(0, r or 12) }, o) end
function M.stroke(o, th, color, border)
	return M.new("UIStroke", { Thickness = th or 3, Color = color or M.C.ink, LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = border and Enum.ApplyStrokeMode.Border or Enum.ApplyStrokeMode.Contextual }, o)
end
function M.light(c, a) return c:Lerp(Color3.new(1, 1, 1), a) end
function M.dark(c, a) return c:Lerp(Color3.new(0, 0, 0), a) end
-- degradado vertical (el fondo debe ser blanco para que se vean los colores)
function M.grad(o, top, bottom)
	o.BackgroundColor3 = Color3.new(1, 1, 1)
	return M.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(top, bottom) }, o)
end

-- texto blanco con contorno oscuro (la firma de los juegos virales)
function M.text(parent, props, strokeTh)
	props.BackgroundTransparency = 1
	props.FontFace = props.FontFace or M.FONT
	props.TextColor3 = props.TextColor3 or M.C.white
	if props.TextScaled == nil then props.TextScaled = true end
	local t = M.new("TextLabel", props, parent)
	if strokeTh ~= 0 then M.stroke(t, strokeTh or 2.5) end
	return t
end

-- panel con borde grueso y brillo
function M.box(parent, props, color, r)
	local f = M.new("Frame", props, parent)
	M.corner(f, r or 16)
	M.stroke(f, 4, M.C.ink, true)
	M.grad(f, M.light(color, 0.25), color)
	return f
end

function M.sound(name, speed, volume)
	local id = Data.SOUNDS[name]
	if not id or id == "" then return end
	local s = M.new("Sound", { SoundId = id, PlaybackSpeed = speed or 1, Volume = volume or 0.5 }, SoundService)
	s:Play()
	Debris:AddItem(s, 4)
end

function M.pop(o, amount)
	local sc = o:FindFirstChild("Pop") or M.new("UIScale", { Name = "Pop" }, o)
	sc.Scale = amount or 1.15
	TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

-- botón gordo con degradado, brillo, rebote al pasar y al pulsar
function M.button(parent, label, color, onClick, props)
	local b = M.new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(160, 48) }, parent)
	for k, v in props or {} do b[k] = v end
	M.corner(b, 12)
	M.stroke(b, 3, M.C.ink, true)
	M.grad(b, M.light(color, 0.35), color).Name = "Fill"
	local shine = M.new("Frame", { Size = UDim2.new(1, -8, 0.42, 0), Position = UDim2.fromOffset(4, 3), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.75, BorderSizePixel = 0 }, b)
	M.corner(shine, 9)
	local t = M.text(b, { Text = label, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.new(1, -12, 0.72, 0) }, 2)
	local sc = M.new("UIScale", {}, b)
	local function to(v) TweenService:Create(sc, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = v }):Play() end
	b.MouseEnter:Connect(function() to(1.06) end)
	b.MouseLeave:Connect(function() to(1) end)
	b.MouseButton1Down:Connect(function() to(0.9) end)
	b.MouseButton1Up:Connect(function() to(1.06) end)
	b.Activated:Connect(function()
		M.sound("click", 1.2, 0.35)
		onClick()
	end)
	return b, t
end
function M.setColor(b, color) b.Fill.Color = ColorSequence.new(M.light(color, 0.35), color) end

-- escala toda la interfaz según la pantalla (celular, tablet, PC)
function M.autoscale(o)
	local sc = M.new("UIScale", {}, o)
	local cam = workspace.CurrentCamera
	local function upd()
		local v = cam.ViewportSize
		sc.Scale = math.clamp(math.min(v.X / 1280, v.Y / 760), 0.55, 1.15)
	end
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(upd)
	upd()
	return sc
end

function M.fmt(n)
	n = math.floor(n)
	if n >= 1e12 then return string.format("%.2fT", n / 1e12)
	elseif n >= 1e9 then return string.format("%.2fB", n / 1e9)
	elseif n >= 1e6 then return string.format("%.2fM", n / 1e6)
	elseif n >= 1e4 then return string.format("%.1fK", n / 1e3) end
	local s = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (s:gsub("^,", ""))
end

return M
