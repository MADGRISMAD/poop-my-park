-- Apertura de sobres a pantalla completa: suspenso, destello y revelado con rayos.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Data = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"))
local UI = require(script.Parent.UI)
local Pets = require(script.Parent.Pets)
local Juice = require(script.Parent.Juice)

local M = {}
local busy = false
local skipped = false -- el jugador pulsó SALTAR: todo lo que queda ocurre al instante
local function wait(t)
	if not skipped then task.wait(t) end
end
local C_GOLD = UI.C.gold

local function tier(r) return r.kind == "dog" and Data.RARITY_IDX[r.dog.rarity] or 0 end
local function tween(o, t, props, style)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad), props)
	tw:Play()
	return tw
end

local function rays(parent, color)
	local holder = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, ZIndex = 61 }, parent)
	for i = 0, 11 do
		local r = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(70, 1500), Rotation = i * 15, BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 61 }, holder)
		UI.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 1) }) }, r)
	end
	return holder
end

local function dogCard(parent, r, order)
	local d = r.dog
	local ra, qu, br = Data.RARITY[d.rarity], Data.QUALITY[d.quality], Data.BREED[d.breed]
	local card = UI.box(parent, { LayoutOrder = order, ZIndex = 62 }, UI.light(ra.color, 0.55), 14)
	card.UIStroke.Color = UI.dark(ra.color, 0.3)
	Pets.viewport(card, d, { Size = UDim2.new(1, 0, 0, 110), ZIndex = 63 })
	UI.text(card, { Text = br.name, Position = UDim2.fromOffset(4, 108), Size = UDim2.new(1, -8, 0, 24), TextColor3 = ra.color, ZIndex = 63 })
	UI.text(card, { Text = ra.name, Position = UDim2.fromOffset(4, 132), Size = UDim2.new(1, -8, 0, 18), ZIndex = 63 }, 2)
	UI.text(card, { Text = qu.name, Position = UDim2.fromOffset(4, 150), Size = UDim2.new(1, -8, 0, 16), TextColor3 = qu.color, ZIndex = 63 }, 2)
	if r.new then
		local b = UI.box(card, { Size = UDim2.fromOffset(64, 24), Position = UDim2.fromOffset(-8, -8), Rotation = -12, ZIndex = 64 }, UI.C.red, 8)
		UI.text(b, { Text = "¡NUEVO!", Size = UDim2.fromScale(1, 1), ZIndex = 65 }, 2)
	end
	return card
end

local function itemCard(parent, r, order)
	local card = UI.box(parent, { LayoutOrder = order, ZIndex = 62 }, UI.C.panel2, 14)
	UI.text(card, { Text = r.icon, Position = UDim2.fromOffset(4, 10), Size = UDim2.new(1, -8, 0, 90), ZIndex = 63 }, 0)
	UI.text(card, { Text = r.name, Position = UDim2.fromOffset(6, 104), Size = UDim2.new(1, -12, 0, 36), ZIndex = 63 }, 2)
	UI.text(card, { Text = "x" .. r.qty, Position = UDim2.fromOffset(4, 142), Size = UDim2.new(1, -8, 0, 22), TextColor3 = UI.C.gold, ZIndex = 63 }, 2)
	return card
end

-- revelado individual de un perro (el gran momento)
local function single(overlay, r, packIcon)
	local t = tier(r)
	local ra = Data.RARITY[r.dog.rarity]
	local pack = UI.text(overlay, { Text = packIcon, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(220, 220), ZIndex = 62 }, 0)
	UI.pop(pack, 0.2)
	wait(0.35)
	for i = 1, 2 + t do -- más suspenso cuanto más raro
		UI.sound("pick", 0.8 + i * 0.12, 0.5)
		tween(pack, 0.07, { Rotation = 14 }); wait(0.07)
		tween(pack, 0.07, { Rotation = -14 }); wait(0.07)
		pack.Rotation = 0
		UI.pop(pack, 1 + i * 0.06)
		wait(0.2)
	end
	local flash = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 70 }, overlay)
	tween(flash, 0.6, { BackgroundTransparency = 1 })
	pack:Destroy()
	if t >= 3 then
		UI.sound("hatch", 1, 0.6)
		Juice.shake(0.4 + t * 0.15, 0.5)
	end

	local spin = rays(overlay, ra.color)
	local vf, model = Pets.viewport(overlay, r.dog, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(380, 380), ZIndex = 63 })
	UI.pop(vf, 0.3)
	local conn = RunService.RenderStepped:Connect(function(dt)
		spin.Rotation += dt * 25
		model:PivotTo(model:GetPivot() * CFrame.Angles(0, dt * 1.2, 0))
	end)
	local rt = UI.text(overlay, { Text = string.upper(ra.name), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.7), Size = UDim2.fromOffset(600, 70), TextColor3 = ra.color, ZIndex = 64 }, 4)
	UI.pop(rt, 1.8)
	local br, qu = Data.BREED[r.dog.breed], Data.QUALITY[r.dog.quality]
	local icons = ""
	for _, id in r.dog.traits do icons ..= Data.TRAITS[id].icon end
	UI.text(overlay, { Text = br.name, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.79), Size = UDim2.fromOffset(500, 44), ZIndex = 64 }, 3)
	UI.text(overlay, { Text = `Calidad {qu.name}  {icons}`, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.86), Size = UDim2.fromOffset(500, 30), TextColor3 = qu.color, ZIndex = 64 }, 2)
	if r.new then
		local b = UI.box(overlay, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.62, 0.2), Size = UDim2.fromOffset(170, 50), Rotation = 10, ZIndex = 66 }, UI.C.red, 12)
		UI.text(b, { Text = "¡NUEVO!", Size = UDim2.fromScale(1, 1), ZIndex = 67 }, 3)
		UI.pop(b, 2)
	end
	return function() conn:Disconnect() end
end

-- varios resultados: cartas que se voltean una a una, la mejor al final
local function multi(overlay, results)
	table.sort(results, function(a, b) return tier(a) < tier(b) end)
	local grid = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(780, 380), BackgroundTransparency = 1, ZIndex = 61 }, overlay)
	UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(140, 170), CellPadding = UDim2.fromOffset(12, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	local backs = {}
	for i in results do
		local b = UI.box(grid, { LayoutOrder = i, ZIndex = 62 }, UI.C.purple, 14)
		UI.text(b, { Text = "?", Size = UDim2.fromScale(1, 1), ZIndex = 63 }, 3)
		backs[i] = b
	end
	wait(0.4)
	for i, r in results do
		if not overlay.Parent then return end
		local t = tier(r)
		if t >= 2 then
			for _ = 1, 3 + t do
				backs[i].Rotation = 6
				wait(0.06)
				backs[i].Rotation = -6
				wait(0.06)
			end
		end
		backs[i]:Destroy()
		local card = r.kind == "dog" and dogCard(grid, r, i) or itemCard(grid, r, i)
		UI.pop(card, 0.4)
		UI.sound("pick", 1 + i * 0.05, 0.4)
		if t >= 3 then
			UI.sound("hatch", 1, 0.5)
			Juice.shake(0.3 + t * 0.1, 0.4)
		end
		wait(t >= 2 and 0.45 or 0.14)
	end
end

-- fusión: los perros vuelan al centro, giran, destello y aparece el nuevo
function M.fusion(gui, inputs, result)
	if busy then return end
	busy = true
	local overlay = UI.new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(15, 8, 30), BackgroundTransparency = 1, ZIndex = 60 }, gui)
	tween(overlay, 0.25, { BackgroundTransparency = 0.1 })
	local n = #inputs
	local frames = {}
	for i, d in inputs do
		local a = (i - 1) / n * math.pi * 2
		local vf = Pets.viewport(overlay, d, { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(170, 170), ZIndex = 62,
			Position = UDim2.new(0.5, math.cos(a) * 260, 0.45, math.sin(a) * 180) })
		UI.pop(vf, 0.2)
		frames[i] = { vf = vf, a = a }
	end
	task.wait(0.6)
	-- giran en espiral hacia el centro cada vez más rápido
	local t0 = os.clock()
	while os.clock() - t0 < 1.4 do
		local e = (os.clock() - t0) / 1.4
		for _, f in frames do
			local a = f.a + e * e * 14
			local r = 1 - e
			f.vf.Position = UDim2.new(0.5, math.cos(a) * 260 * r, 0.45, math.sin(a) * 180 * r)
			f.vf.Rotation = e * 360
		end
		task.wait()
	end
	for _, f in frames do f.vf:Destroy() end
	local flash = UI.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 70 }, overlay)
	tween(flash, 0.7, { BackgroundTransparency = 1 })
	UI.sound("hatch", 1.1, 0.6)
	Juice.shake(0.6, 0.5)
	local ra = Data.RARITY[result.rarity]
	local spin = rays(overlay, ra.color)
	local vf, model = Pets.viewport(overlay, result, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(400, 400), ZIndex = 63 })
	UI.pop(vf, 0.3)
	local conn = RunService.RenderStepped:Connect(function(dt)
		spin.Rotation += dt * 30
		model:PivotTo(model:GetPivot() * CFrame.Angles(0, dt * 1.2, 0))
	end)
	local title = UI.text(overlay, { Text = `¡FUSIÓN {Data.FUSION.Stars[result.fusion]}!`, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.7), Size = UDim2.fromOffset(600, 70), TextColor3 = C_GOLD, ZIndex = 64 }, 4)
	UI.pop(title, 1.8)
	UI.text(overlay, { Text = `{Data.BREED[result.breed].name} · {Data.sizeLabel(result.size)} ({result.size}) · x{Data.fusionMult(result.fusion)} popó {Data.mutationIcons(result.mutations)}`,
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.fromOffset(700, 36), ZIndex = 64 }, 3)
	local hint = UI.text(overlay, { Text = "Toca para continuar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(400, 32), ZIndex = 64 }, 2)
	UI.pop(hint, 0.5)
	overlay.Activated:Wait()
	conn:Disconnect()
	overlay:Destroy()
	busy = false
end

function M.play(gui, results, packId)
	if busy then return end
	busy, skipped = true, false
	local overlay = UI.new("TextButton", { Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(15, 8, 30), BackgroundTransparency = 1, ZIndex = 60 }, gui)
	tween(overlay, 0.25, { BackgroundTransparency = 0.15 })
	local skip = UI.button(overlay, "⏩ SALTAR", UI.C.orange, function() skipped = true end,
		{ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 24), Size = UDim2.fromOffset(190, 56), ZIndex = 80 })
	local cleanup
	if #results == 1 and results[1].kind == "dog" then
		cleanup = single(overlay, results[1], Data.PACK[packId].icon)
	else
		multi(overlay, results)
	end
	skip:Destroy()
	local hint = UI.text(overlay, { Text = "Toca para continuar", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(400, 32), ZIndex = 64 }, 2)
	UI.pop(hint, 0.5)
	overlay.Activated:Wait()
	if cleanup then cleanup() end
	overlay:Destroy()
	busy = false
end

return M
