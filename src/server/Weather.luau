-- Clima global: eventos aleatorios con efectos y probabilidad de mutar a los perros.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage.Shared.Data)
local State = require(script.Parent.State)
local Dogs = require(script.Parent.Dogs)

local rng = Random.new()
local M = { current = nil }

local function weightedPick()
	local total = 0
	for _, w in Data.WEATHERS do total += w.weight end
	local r = rng:NextNumber() * total
	for id, w in Data.WEATHERS do
		r -= w.weight
		if r <= 0 then return id end
	end
	return "lluvia"
end

local function set(id, dur)
	M.current = id
	workspace:SetAttribute("Weather", id or "")
	workspace:SetAttribute("WeatherEnds", id and os.time() + dur or 0)
	if id then
		local w = Data.WEATHERS[id]
		State.NotifyEv:FireAllClients(`{w.icon} ¡{string.upper(w.name)}!`, "banner", w.desc)
	else
		State.NotifyEv:FireAllClients("☀️ El clima se calmó", "toast")
	end
end

local function randomYardPoint(S)
	local h = Data.YARD.Half - 4
	return Data.yardRel(S.slot, rng:NextNumber(-h, h), rng:NextNumber(-h, h))
end

-- un meteorito cae; los perros cerca del impacto pueden volverse cósmicos
local function meteor(S)
	local pos = randomYardPoint(S)
	for _, g in S.gear do -- la antena atrae meteoritos
		if g.id == "antena" and rng:NextNumber() < 0.5 then
			pos = g.pos + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
		end
	end
	State.FxEv:FireAllClients("meteor", pos)
	task.delay(1.1, function()
		if S.dead then return end
		for id, run in S.run do
			if (run.pos - pos).Magnitude < 10 and rng:NextNumber() < 0.4 then Dogs.mutate(S, S.data.dogs[id], "cosmico") end
		end
	end)
end

task.spawn(function()
	workspace:SetAttribute("Weather", "")
	local first = true
	while true do
		task.wait(first and 40 or rng:NextInteger(Data.WEATHER_GAP[1], Data.WEATHER_GAP[2])) -- el primero llega rápido
		first = false
		local id = weightedPick()
		local w = Data.WEATHERS[id]
		local dur = rng:NextInteger(w.dur[1], w.dur[2])
		set(id, dur)
		local t = 0
		while t < dur do
			local step = rng:NextNumber(1.5, 3.5)
			task.wait(step)
			t += step
			for _, S in State.sessions do
				if id == "tormenta" and rng:NextNumber() < 0.5 then State.FxEv:FireAllClients("bolt", randomYardPoint(S)) end
				if id == "meteoritos" then meteor(S) end
			end
		end
		set(nil)
	end
end)

-- cada segundo: probabilidad de mutación de cada perro según clima y equipo cercano
function M.tick(S, dt)
	local w = M.current and Data.WEATHERS[M.current]
	for id, run in S.run do
		local rates = {}
		if w then
			for m, r in w.mut do rates[m] = r end
		end
		for _, g in S.gear do
			local def = Data.GEAR[g.id]
			if (g.pos - run.pos).Magnitude <= def.radius then
				rates[def.mut] = (rates[def.mut] or 0) * def.boost + def.passive
			end
		end
		rates.dorado = (rates.dorado or 0) + Data.GOLDEN_PASSIVE
		local bias = Data.ZONES[S.data.park].bias
		local storm = 1 + 0.15 * State.perk(S, "storm")
		for m, r in rates do
			if rng:NextNumber() < r * dt * (bias[m] or 1) * storm then
				if m == "electrificado" then State.FxEv:FireAllClients("bolt", run.pos) end
				Dogs.mutate(S, S.data.dogs[id], m)
			end
		end
	end
end

return M
