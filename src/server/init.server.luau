local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Shared.Data)
local State = require(script.State)
local Dogs = require(script.Dogs)
local Packs = require(script.Packs)
local Poop = require(script.Poop)
local Progress = require(script.Progress)
local Park = require(script.Park)
local Meta = require(script.Meta)
local Weather = require(script.Weather)
local Gear = require(script.Gear)

local sessions = State.sessions
local slots = {} -- slot -> player

-- kiosco: abre la pestaña de sobres en el cliente
local prompt = Instance.new("ProximityPrompt")
prompt.ActionText = "Comprar sobres"
prompt.ObjectText = "Tienda de sobres"
prompt.MaxActivationDistance = 12
prompt.Parent = Park.pack
prompt.Triggered:Connect(function(player) State.UIEv:FireClient(player, "packs", Park.pack.Position) end)
local gearPrompt = prompt:Clone()
gearPrompt.ActionText, gearPrompt.ObjectText = "Ver equipo", "Tienda de equipo"
gearPrompt.Parent = Park.gear
gearPrompt.Triggered:Connect(function(player) State.UIEv:FireClient(player, "gear", Park.gear.Position) end)

-- las tiendas de sobres y equipo solo funcionan estando junto al quiosco
local function near(S, part)
	local char = S.player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	return hrp ~= nil and (hrp.Position - part.Position).Magnitude <= 22
end

local function goHome(S)
	local char = S.player.Character
	if char then -- justo dentro de la entrada, mirando al fondo del parque
		local at = Data.yardRel(S.slot, 0, -Data.YARD.Half + 6) + Vector3.new(0, 4, 0)
		char:PivotTo(CFrame.lookAt(at, Data.yardCenter(S.slot) + Vector3.new(0, 4, 0)))
	end
end

Players.PlayerAdded:Connect(function(player)
	local slot
	for i = 1, Data.SLOTS do
		if not slots[i] then slot = i break end
	end
	if not slot then
		player:Kick("Servidor lleno (máximo " .. Data.SLOTS .. " jugadores)")
		return
	end
	slots[slot] = player

	local data, isNew, canSave = State.load(player)
	local S = {
		player = player, data = data, slot = slot, origin = Data.yardCenter(slot), canSave = canSave,
		combo = { mult = 1, last = 0 }, fever = { value = 0, active = false, untilT = 0 },
		poopCount = 0, poops = {}, run = {}, bowls = {}, mProg = 0, dirty = true, dead = false,
		joined = os.clock(), gifts = {}, gear = {},
	}
	sessions[player] = S
	player:SetAttribute("Slot", slot)
	data.park = math.clamp(data.park, 1, data.zones)
	function S.onZones()
		Park.setPark(slot, data.park, player.DisplayName)
		S.dirty = true
	end
	S.onZones()

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player
	for _, name in { "Popó", "Renac." } do
		local v = Instance.new("IntValue")
		v.Name = name
		v.Parent = stats
	end

	S.folder = Instance.new("Folder")
	S.folder.Name = "Patio_" .. player.UserId
	S.folder.Parent = workspace
	Dogs.syncBowls(S)
	Gear.restore(S)

	if isNew then
		for _, sex in { "M", "F" } do
			Dogs.activate(S, Dogs.create(S, { breed = "callejero", age = "adult", sex = sex }).id)
		end
	else
		local lastSaved, ids = data.lastSaved, data.active
		data.active = {}
		for _, id in ids do Dogs.activate(S, id) end
		Progress.offline(S, lastSaved)
	end

	player.CharacterAdded:Connect(function() task.defer(goHome, S) end)
	if player.Character then goHome(S) end
end)

Players.PlayerRemoving:Connect(function(player)
	local S = sessions[player]
	if not S then return end
	S.dead = true
	State.save(S)
	S.folder:Destroy()
	Dogs.removePets(S)
	Park.setPark(S.slot, 1, nil)
	slots[S.slot] = nil
	sessions[player] = nil
end)

game:BindToClose(function()
	for _, S in sessions do State.save(S) end
end)

-- acciones del cliente ------------------------------------------------------
local function buy(S, cost, apply)
	if S.data.poop < cost then return { ok = false, msg = "No te alcanza 💩" } end
	S.data.poop -= cost
	apply()
	return { ok = true }
end

State.Do.OnServerInvoke = function(player, action, a, b)
	local S = sessions[player]
	if not S or typeof(action) ~= "string" then return { ok = false } end
	local d = S.data
	S.dirty = true
	if (action == "buyPack" or action == "openPack") and not near(S, Park.pack) then
		return { ok = false, msg = "Ve caminando al quiosco de SOBRES 🎁" }
	elseif action == "buyItem" and not near(S, Park.gear) then
		return { ok = false, msg = "Ve caminando al quiosco de EQUIPO 🧰" }
	end
	if action == "buyPack" then
		return { ok = Packs.buy(S, a, b) }
	elseif action == "openPack" then
		local r = Packs.open(S, a, b == true)
		return { ok = r ~= nil, results = r }
	elseif action == "activate" then
		return { ok = Dogs.activate(S, a), msg = "Parque lleno" }
	elseif action == "deactivate" then
		return { ok = Dogs.deactivate(S, a) }
	elseif action == "equipBest" then
		Dogs.equipBest(S)
		return { ok = true }
	elseif action == "buyUpgrade" then
		local u = Data.UPGRADE[a]
		local lvl = u and d.upgrades[a] or 0
		if not u or lvl >= u.max then return { ok = false } end
		return buy(S, u.cost(lvl), function()
			d.upgrades[a] = lvl + 1
			if a == "magnet" then
				for _, m in S.folder:GetChildren() do
					if m.Name == "Caca" then
						local z = m.Zona
						z.Size = Vector3.new(3 + 2 * State.upg(S, "magnet"), 4, 3 + 2 * State.upg(S, "magnet"))
					end
				end
			end
		end)
	elseif action == "buyObject" then
		local o = Data.OBJECT[a]
		local have = o and d.objects[a] or 0
		if not o or have >= o.max then return { ok = false } end
		return buy(S, o.cost, function()
			d.objects[a] = have + 1
			Dogs.syncBowls(S)
	Gear.restore(S)
		end)
	elseif action == "buyFood" then
		local f = Data.FOOD[a]
		if not f then return { ok = false } end
		return buy(S, math.ceil(f.cost * State.mods(S).foodCost), function() d.food[a] = (d.food[a] or 0) + 1 end)
	elseif action == "selectFood" then
		if Data.FOOD[a] then d.selectedFood = a end
		return { ok = true }
	elseif action == "buyPark" then
		return Meta.buyPark(S, a)
	elseif action == "selectPark" then
		return Meta.selectPark(S, a)
	elseif action == "buyPerk" then
		return Meta.buyPerk(S, a)
	elseif action == "rebirth" then
		return { ok = Meta.rebirth(S) }
	elseif action == "claimDaily" then
		return { ok = Meta.claimDaily(S) }
	elseif action == "claimGift" then
		return { ok = Meta.claimGift(S, a) }
	elseif action == "redeem" then
		return Meta.redeem(S, a)
	elseif action == "fuse" then
		return Dogs.fuse(S, a)
	elseif action == "claimQuest" then
		return Meta.claimQuest(S, a)
	elseif action == "claimIndex" then
		return Meta.claimIndex(S, a)
	elseif action == "buyItem" then
		return Gear.buy(S, a)
	elseif action == "placeGear" then
		return Gear.place(S, a)
	elseif action == "useSpray" then
		return Gear.useSpray(S, a, b)
	elseif action == "home" then
		goHome(S)
		return { ok = true }
	end
	return { ok = false }
end

-- bucles ----------------------------------------------------------------------
task.spawn(function() -- simulación
	local acc = 0
	while true do
		local dt = task.wait(0.25)
		acc += dt
		for _, S in sessions do
			Dogs.tick(S, dt)
			Dogs.assign(S)
			Poop.tick(S, dt)
			if acc >= 1 then
				Progress.tick(S)
				Weather.tick(S, acc)
				Dogs.fights(S)
				Dogs.moods(S)
			end
			S.player.leaderstats["Popó"].Value = S.data.poop
			S.player.leaderstats["Renac."].Value = S.data.rebirths
		end
		if acc >= 1 then acc = 0 end
	end
end)

task.spawn(function() -- sincroniza el estado con el cliente
	while true do
		task.wait(0.25)
		for player, S in sessions do
			if S.dirty then
				S.dirty = false
				State.StateEv:FireClient(player, State.snapshot(S))
			end
		end
	end
end)

-- bonus por amigos en el servidor
local function updateFriends()
	for p, S in sessions do
		local n = 0
		for _, other in Players:GetPlayers() do
			if other ~= p then
				local ok, isFriend = pcall(p.IsFriendsWith, p, other.UserId)
				if ok and isFriend then n += 1 end
			end
		end
		S.friends = n
		S.dirty = true
	end
end
Players.PlayerAdded:Connect(function() task.wait(2) updateFriends() end)
Players.PlayerRemoving:Connect(function() task.defer(updateFriends) end)

local function short(n)
	if n >= 1e12 then return string.format("%.1fT", n / 1e12) elseif n >= 1e9 then return string.format("%.1fB", n / 1e9)
	elseif n >= 1e6 then return string.format("%.1fM", n / 1e6) elseif n >= 1e3 then return string.format("%.1fK", n / 1e3) end
	return tostring(math.floor(n))
end
task.spawn(function() -- tablero de líderes
	while true do
		local list = {}
		for p, S in sessions do table.insert(list, { p.DisplayName, S.data.rebirths, S.data.stats.totalPoop }) end
		table.sort(list, function(a, b) return a[2] ~= b[2] and a[2] > b[2] or a[3] > b[3] end)
		local lines = { "🏆 LÍDERES DEL SERVIDOR" }
		for i, e in list do
			if i > 8 then break end
			table.insert(lines, `{i}. {e[1]}  🔄{e[2]}  💩{short(e[3])}`)
		end
		Park.setBoard(table.concat(lines, "\n"))
		task.wait(5)
	end
end)

task.spawn(function() -- autoguardado
	while true do
		task.wait(20)
		for _, S in sessions do State.save(S) end
	end
end)
