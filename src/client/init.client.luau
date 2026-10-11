local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local R = ReplicatedStorage:WaitForChild("Remotes")
local Data = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"))
local UI = require(script.UI)
local Juice = require(script.Juice)
local Hud = require(script.Hud)
local Panels = require(script.Panels)
require(script.Weather)
local Title = require(script.Title)
local CameraMode = require(script.CameraMode)

local gui = UI.new("ScreenGui", { Name = "PopoUI", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, Players.LocalPlayer:WaitForChild("PlayerGui"))

local hud
local function act(action, a, b)
	local res = R.Do:InvokeServer(action, a, b)
	if res and not res.ok and res.msg then hud.toast(res.msg) end
	return res
end

local panels = Panels.new(gui, act)
hud = Hud.new(gui, panels.open, function() act("home") end, Panels.TABS, Panels.ORDER, Panels.RIGHT)

local snapAt
local function giftsReady(s, now)
	local n, claimed = 0, {}
	for _, i in s.gifts do claimed[i] = true end
	for i, g in Data.GIFTS do
		if not claimed[i] and s.session + (now - snapAt) >= g.t then n += 1 end
	end
	return n
end
R.State.OnClientEvent:Connect(function(s)
	snapAt = os.clock()
	hud.update(s)
	panels.update(s)
	hud.setBadge("daily", s.daily.can and 1 or 0)
	hud.setBadge("gifts", giftsReady(s, os.clock()))
	local questsReady, indexReady = 0, 0
	for _, q in s.quests do
		if q.progress >= q.target and not q.claimed then questsReady += 1 end
	end
	for i, r in Data.INDEX_REWARDS do
		if #s.discovered >= r.n and not table.find(s.indexClaimed, i) then indexReady += 1 end
	end
	hud.setBadge("quests", questsReady)
	hud.setBadge("index", indexReady)
	hud.setBadge("dogs", #Panels.fusionSuggestions(s.dogs))
end)
R.Notify.OnClientEvent:Connect(function(msg, kind, sub)
	if kind == "banner" then
		hud.banner(msg, sub)
		Juice.shake(0.5, 0.4)
	else
		hud.toast(sub and (msg .. " " .. sub) or msg)
	end
end)
-- los quioscos abren su tienda; si te alejas caminando, se cierra
local kioskPos
R.OpenUI.OnClientEvent:Connect(function(tab, pos)
	kioskPos = pos
	if panels.tab() ~= tab then panels.open(tab) end
end)
game:GetService("RunService").Heartbeat:Connect(function()
	local t = panels.tab()
	if not kioskPos or (t ~= "packs" and t ~= "gear") then return end
	local char = Players.LocalPlayer.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp and (hrp.Position - kioskPos).Magnitude > 22 then
		panels.close()
		kioskPos = nil
	end
end)
R.Announce.OnClientEvent:Connect(hud.announce)

-- cada popó cobrada: número flotante, sonido que sube de tono con el combo y ícono volando al contador
R.Collected.OnClientEvent:Connect(function(pos, earned, kind, combo, auto)
	local top = pos + Vector3.new(0, 3, 0)
	local gold = kind ~= "normal"
	Juice.floatText(top, "+" .. UI.fmt(earned), gold and UI.C.gold or UI.C.white, kind == "rainbow")
	Juice.burst(top, gold and UI.C.gold or Color3.fromRGB(140, 90, 40), gold and 24 or 8)
	UI.sound(gold and "gold" or "pick", 0.9 + math.min(combo, 10) * 0.08, auto and 0.25 or 0.5)
	if kind == "golden" then Juice.shake(0.25, 0.2) end
	if kind == "rainbow" then Juice.shake(0.8, 0.6) end
	task.spawn(Juice.fly, gui, top, hud.coin, gold and "⭐" or "💩", hud.bump)
end)

CameraMode.init(function(on)
	if on then hud.toast("🗺️ VISTA AÉREA · acerca con la rueda para volver") end
end)

-- pantalla de inicio (el HUD se muestra al terminar)
task.spawn(Title.play, gui)
