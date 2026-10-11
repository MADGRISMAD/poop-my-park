-- Efectos: texto flotante, monedas que vuelan al contador, partículas y sacudida de cámara.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local UI = require(script.Parent.UI)

local M = {}
local cam = workspace.CurrentCamera
local fx = UI.new("Folder", { Name = "Efectos" }, workspace)

local shakeT, shakeMag, shaking = 0, 0, false
function M.shake(mag, dur)
	shakeMag, shakeT = math.max(shakeMag, mag), math.max(shakeT, dur)
end
RunService.RenderStepped:Connect(function(dt)
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	if shakeT > 0 then
		shakeT -= dt
		shaking = true
		local m = shakeMag * math.max(shakeT, 0) * 4
		hum.CameraOffset = Vector3.new((math.random() - 0.5) * m, (math.random() - 0.5) * m, 0)
	elseif shaking then
		shaking, shakeMag = false, 0
		hum.CameraOffset = Vector3.zero
	end
end)

local function anchor(pos)
	return UI.new("Part", { Transparency = 1, Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, Size = Vector3.one * 0.2, Position = pos }, fx)
end

function M.floatText(pos, text, color, big)
	local p = anchor(pos)
	local g = UI.new("BillboardGui", { Size = UDim2.fromOffset(big and 260 or 150, big and 80 or 50), AlwaysOnTop = true }, p)
	local t = UI.text(g, { Text = text, Size = UDim2.fromScale(1, 1), TextColor3 = color }, 3)
	UI.pop(t, 1.6)
	TweenService:Create(p, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = pos + Vector3.new(0, 6, 0) }):Play()
	task.delay(0.5, function()
		TweenService:Create(t, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		TweenService:Create(t.UIStroke, TweenInfo.new(0.4), { Transparency = 1 }):Play()
	end)
	Debris:AddItem(p, 1)
end

function M.burst(pos, color, n)
	local p = anchor(pos)
	local e = UI.new("ParticleEmitter", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds", Color = ColorSequence.new(color),
		Lifetime = NumberRange.new(0.4, 0.8), Speed = NumberRange.new(10, 22), SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(0.8, 0), Rate = 0, Acceleration = Vector3.new(0, -30, 0),
	}, p)
	e:Emit(n or 12)
	Debris:AddItem(p, 1.5)
end

local flying = 0
-- un ícono sale del mundo y vuela hasta el contador; al llegar llama onArrive
function M.fly(gui, worldPos, target, icon, onArrive)
	if flying > 25 then
		onArrive()
		return
	end
	local v, onScreen = cam:WorldToViewportPoint(worldPos)
	if not onScreen then
		onArrive()
		return
	end
	flying += 1
	local l = UI.text(gui, { Text = icon, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(v.X, v.Y), Size = UDim2.fromOffset(44, 44), ZIndex = 40 }, 0)
	local goal = target.AbsolutePosition + target.AbsoluteSize / 2
	local mid = UDim2.fromOffset(v.X + (math.random() - 0.5) * 120, v.Y - 60)
	local t1 = TweenService:Create(l, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = mid })
	t1:Play()
	t1.Completed:Wait()
	local t2 = TweenService:Create(l, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromOffset(goal.X, goal.Y), Size = UDim2.fromOffset(26, 26) })
	t2:Play()
	t2.Completed:Wait()
	l:Destroy()
	flying -= 1
	onArrive()
end

return M
