-- HUD: contador de popó, nivel, combo, fiebre, misión, menú lateral y avisos.
local TweenService = game:GetService("TweenService")
local TextChatService = game:GetService("TextChatService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"))
local UI = require(script.Parent.UI)
local C = UI.C

local M = {}

function M.new(gui, onTab, onHome, tabs, order, rightOrder)
	local self = {}

	-- dinero y nivel (arriba a la izquierda)
	local left = UI.new("Frame", { Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(300, 120), BackgroundTransparency = 1 }, gui)
	UI.autoscale(left)
	local money = UI.box(left, { Position = UDim2.fromOffset(34, 6), Size = UDim2.fromOffset(250, 58) }, C.brown, 29)
	self.moneyText = UI.text(money, { Position = UDim2.fromOffset(46, 6), Size = UDim2.new(1, -60, 1, -12), TextXAlignment = Enum.TextXAlignment.Left }, 3)
	local coin = UI.box(left, { Size = UDim2.fromOffset(70, 70) }, C.gold, 35)
	self.coin = UI.text(coin, { Text = "💩", Size = UDim2.fromScale(0.8, 0.8), Position = UDim2.fromScale(0.1, 0.08) }, 0)
	local lvl = UI.box(left, { Position = UDim2.fromOffset(8, 74), Size = UDim2.fromOffset(46, 46) }, C.purple, 23)
	self.lvlText = UI.text(lvl, { Size = UDim2.new(1, -6, 1, -10), Position = UDim2.fromOffset(3, 5) }, 2.5)
	local xpBack = UI.box(left, { Position = UDim2.fromOffset(60, 86), Size = UDim2.fromOffset(190, 22) }, UI.dark(C.purple, 0.5), 11)
	self.xpFill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, xpBack)
	UI.corner(self.xpFill, 11)
	UI.grad(self.xpFill, UI.light(C.purple, 0.5), C.purple)
	self.xpText = UI.text(xpBack, { Size = UDim2.new(1, 0, 1, -4), Position = UDim2.fromOffset(0, 2), ZIndex = 2 }, 2)

	-- combo y fiebre (arriba al centro)
	local center = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(460, 150), BackgroundTransparency = 1 }, gui)
	UI.autoscale(center)
	local fever = UI.box(center, { Size = UDim2.fromOffset(460, 34) }, UI.dark(C.purple, 0.55), 17)
	self.feverFill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, fever)
	UI.corner(self.feverFill, 17)
	self.feverGrad = UI.new("UIGradient", { Color = ColorSequence.new(C.pink, C.orange) }, self.feverFill)
	self.feverText = UI.text(fever, { Text = "🔥 FIEBRE", Size = UDim2.new(1, 0, 1, -8), Position = UDim2.fromOffset(0, 4), ZIndex = 2 }, 2.5)
	local weatherChip = UI.box(center, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.fromOffset(300, 38), Visible = false }, C.blue, 19)
	local weatherText = UI.text(weatherChip, { Size = UDim2.new(1, -16, 1, -10), Position = UDim2.fromOffset(8, 5) }, 2.5)
	task.spawn(function()
		while true do
			local id = workspace:GetAttribute("Weather") or ""
			weatherChip.Visible = id ~= ""
			if id ~= "" then
				local w = Data.WEATHERS[id]
				local left = math.max(0, (workspace:GetAttribute("WeatherEnds") or 0) - workspace:GetServerTimeNow())
				weatherText.Text = string.format("%s %s %d:%02d", w.icon, string.upper(w.name), left // 60, left % 60)
			end
			task.wait(0.5)
		end
	end)
	self.combo = UI.text(center, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 84), Size = UDim2.fromOffset(300, 56), TextColor3 = C.gold, Visible = false }, 4)
	self.combo.Rotation = -4

	-- menú lateral (botones cuadrados)
	local menu = UI.new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 70), Size = UDim2.fromOffset(296, 296), BackgroundTransparency = 1 }, gui)
	UI.autoscale(menu)
	UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(92, 92), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, menu)
	local badges = {}
	local function addBadge(b, t)
		local badge = UI.box(b, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(32, 32), Visible = false, ZIndex = 3 }, C.red, 16)
		badges[t] = { badge, UI.text(badge, { Size = UDim2.new(1, -6, 1, -8), Position = UDim2.fromOffset(3, 4), ZIndex = 4 }, 2) }
	end
	local function square(i, icon, label, color, cb)
		local b = UI.button(menu, "", color, cb, { LayoutOrder = i })
		UI.text(b, { Text = icon, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 54) }, 0)
		UI.text(b, { Text = label, Position = UDim2.fromOffset(2, 60), Size = UDim2.new(1, -4, 0, 24) }, 2.5)
		return b
	end
	for i, t in order do
		local def = tabs[t]
		addBadge(square(i, def.icon, def.title:match("%S+$"), def.color, function() onTab(t) end), t)
	end
	square(#order + 1, "🏠", "PARQUE", C.green, onHome)

	-- recompensas (derecha), con globo rojo cuando hay algo que reclamar
	local right = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(196, 300), BackgroundTransparency = 1 }, gui)
	UI.autoscale(right)
	UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(92, 92), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, right)
	for i, t in rightOrder do
		local def = tabs[t]
		local b = UI.button(right, "", def.color, function() onTab(t) end, { LayoutOrder = i, Size = UDim2.fromOffset(92, 92) })
		UI.text(b, { Text = def.icon, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 54) }, 0)
		UI.text(b, { Text = def.title:match("%S+$"), Position = UDim2.fromOffset(2, 60), Size = UDim2.new(1, -4, 0, 24) }, 2.5)
		addBadge(b, t)
	end
	function self.setBadge(t, n)
		local e = badges[t]
		if not e then return end
		local was = e[1].Visible
		e[1].Visible = n > 0
		e[2].Text = n > 9 and "9+" or tostring(n)
		if n > 0 and not was then UI.pop(e[1], 1.6) end
	end

	-- boosts activos (debajo del nivel)
	local boostRow = UI.new("Frame", { Position = UDim2.fromOffset(8, 128), Size = UDim2.fromOffset(300, 40), BackgroundTransparency = 1 }, left)
	UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }, boostRow)
	local boostChips = {}
	for id, b in Data.BOOSTS do
		local chip = UI.box(boostRow, { Size = UDim2.fromOffset(140, 36), Visible = false }, id == "poop" and C.orange or C.green, 18)
		boostChips[id] = { chip, UI.text(chip, { Size = UDim2.new(1, -12, 1, -10), Position = UDim2.fromOffset(6, 5) }, 2), b }
	end
	left.Size = UDim2.fromOffset(300, 170)
	local friendChip = UI.box(boostRow, { Size = UDim2.fromOffset(110, 36), Visible = false, LayoutOrder = 9 }, C.blue, 18)
	local friendText = UI.text(friendChip, { Size = UDim2.new(1, -12, 1, -10), Position = UDim2.fromOffset(6, 5) }, 2)

	-- misión (abajo al centro)
	local mission = UI.box(gui, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.fromOffset(520, 76) }, C.panel, 18)
	UI.autoscale(mission)
	UI.text(mission, { Text = "📜", Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(56, 56) }, 0)
	self.mTitle = UI.text(mission, { Position = UDim2.fromOffset(74, 6), Size = UDim2.new(1, -86, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.orange }, 2.5)
	local mBack = UI.new("Frame", { Position = UDim2.fromOffset(74, 42), Size = UDim2.new(1, -86, 0, 22), BackgroundColor3 = UI.dark(C.panel, 0.2), BorderSizePixel = 0 }, mission)
	UI.corner(mBack, 11)
	self.mFill = UI.new("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, mBack)
	UI.corner(self.mFill, 11)
	UI.grad(self.mFill, UI.light(C.green, 0.4), C.green)
	self.mText = UI.text(mBack, { Size = UDim2.new(1, 0, 1, -4), Position = UDim2.fromOffset(0, 2), ZIndex = 2 }, 2)

	-- avisos
	local toast = UI.box(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 170), Size = UDim2.fromOffset(520, 46), Visible = false }, C.ink, 14)
	UI.autoscale(toast)
	local toastText = UI.text(toast, { Size = UDim2.new(1, -20, 1, -12), Position = UDim2.fromOffset(10, 6) }, 2)
	local toastN = 0
	function self.toast(msg)
		toastN += 1
		local n = toastN
		toastText.Text = msg
		toast.Visible = true
		UI.pop(toast, 0.8)
		task.delay(2.6, function()
			if n == toastN then toast.Visible = false end
		end)
	end

	local banner = UI.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.32), Size = UDim2.fromOffset(760, 140), BackgroundTransparency = 1, Visible = false }, gui)
	UI.autoscale(banner)
	local bMain = UI.text(banner, { Size = UDim2.new(1, 0, 0, 90), TextColor3 = C.gold }, 5)
	local bSub = UI.text(banner, { Position = UDim2.fromOffset(0, 94), Size = UDim2.new(1, 0, 0, 40) }, 3)
	local bannerN = 0
	function self.banner(msg, sub)
		bannerN += 1
		local n = bannerN
		bMain.Text, bSub.Text = msg, sub or ""
		banner.Visible = true
		bMain.Rotation = -3
		UI.pop(bMain, 2)
		UI.pop(bSub, 0.4)
		task.delay(2.4, function()
			if n == bannerN then banner.Visible = false end
		end)
	end

	-- anuncio global cuando alguien saca un perro legendario o mejor
	local ann = UI.box(gui, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -80), Size = UDim2.fromOffset(640, 56) }, C.purple, 16)
	UI.autoscale(ann)
	local annText = UI.text(ann, { Size = UDim2.new(1, -24, 1, -14), Position = UDim2.fromOffset(12, 7) }, 2.5)
	local annN = 0
	function self.announce(msg, color)
		annN += 1
		local n = annN
		annText.Text = "📢 " .. msg
		UI.setColor(ann, color)
		TweenService:Create(ann, TweenInfo.new(0.4, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 200) }):Play()
		task.delay(4, function()
			if n == annN then TweenService:Create(ann, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -80) }):Play() end
		end)
		pcall(function()
			TextChatService.TextChannels.RBXGeneral:DisplaySystemMessage(`<font color="#{color:ToHex()}">📢 {msg}</font>`)
		end)
	end
	ann.UIGradient.Name = "Fill"

	-- el contador "rueda" hasta el valor real en vez de saltar
	local shown, target = 0, 0
	game:GetService("RunService").RenderStepped:Connect(function(dt)
		if shown ~= target then
			shown += (target - shown) * math.min(1, dt * 8)
			if math.abs(target - shown) < 1 then shown = target end
			self.moneyText.Text = UI.fmt(shown)
		end
	end)

	-- los botones de los menús flotan suavemente
	local floaters = {}
	for _, holder in { menu, right } do
		for _, b in holder:GetChildren() do
			if b:IsA("TextButton") then table.insert(floaters, b) end
		end
	end
	game:GetService("RunService").RenderStepped:Connect(function()
		local t = os.clock()
		for i, b in floaters do b.Rotation = math.sin(t * 1.6 + i * 0.8) * 2.5 end
	end)

	local lastPoop, lastCombo = nil, 1
	function self.update(s)
		target = s.poop
		friendChip.Visible = s.friends > 0
		friendText.Text = `👥 +{math.round(s.friends * Data.FRIEND_BONUS * 100)}%`
		for id, e in boostChips do
			local secs = s.boosts[id]
			e[1].Visible = secs > 0
			e[2].Text = string.format("%s %s %d:%02d", e[3].icon, e[3].name, secs // 60, secs % 60)
		end
		if lastPoop and s.poop < lastPoop then UI.pop(self.moneyText, 0.9) end
		lastPoop = s.poop
		self.lvlText.Text = tostring(s.level)
		self.xpFill.Size = UDim2.fromScale(math.clamp(s.xp / s.xpNext, 0, 1), 1)
		self.xpText.Text = `{s.xp}/{s.xpNext} XP`
		self.feverFill.Size = UDim2.fromScale(math.clamp(s.fever / Data.ECONOMY.FeverMax, 0, 1), 1)
		self.feverText.Text = s.feverActive and "🔥 ¡FIEBRE x2! 🔥" or "🔥 FIEBRE"
		self.combo.Visible = s.combo > 1.05
		self.combo.Text = string.format("x%.1f COMBO!", s.combo)
		if s.combo > lastCombo + 0.05 then UI.pop(self.combo, 1.25) end
		lastCombo = s.combo
		local m = s.mission
		mission.Visible = m ~= nil
		if m then
			self.mTitle.Text = m.title
			self.mFill.Size = UDim2.fromScale(math.clamp(m.progress / m.target, 0, 1), 1)
			self.mText.Text = `{UI.fmt(m.progress)} / {UI.fmt(m.target)}`
		end
	end

	-- la popó cobrada "llega" al contador
	function self.bump() UI.pop(self.coin, 1.35) end

	return self
end

return M
