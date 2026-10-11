-- Popó: valor, aparición, recolección (pisándola o con tus perros), combo y fiebre.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Data = require(ReplicatedStorage.Shared.Data)
local State = require(script.Parent.State)
local Progress = require(script.Parent.Progress)

local E, H = Data.ECONOMY, Data.HOOKS
local rng = Random.new()
local M = {}

local function tm(dog, id, m) return State.hasTrait(dog, id) and m or 1 end
M.traitMult = tm

function M.value(S, dog)
	local breed = Data.BREED[dog.breed]
	local base = breed.produce * Data.RARITY[dog.rarity].mult * Data.QUALITY[dog.quality].mult
	local v = base * State.upg(S, "value") * Data.DOG.AgeMult[dog.age]
		* tm(dog, "digestion", 1.15) * tm(dog, "iman", 1.15) * tm(dog, "fantasma", 2)
		* (1 + (dog.level - 1) * Data.DOG.LevelProdBonus) * State.mods(S).prod * Data.rebirthMult(S.data.rebirths)
		* Data.mutationMult(dog.mutations) * (1 + 0.25 * State.perk(S, "bags"))
		* (dog.size or 1) * Data.fusionMult(dog.fusion) * (1 + Data.FRIEND_BONUS * math.min(S.friends or 0, 5))
	return math.max(1, math.round(v))
end

local function startFever(S)
	local f = S.fever
	f.active, f.untilT = true, os.clock() + E.FeverDuration
	S.data.stats.fever += 1
	State.notify(S, "¡FIEBRE DEL PARQUE!", "banner", "Todo vale x2 · ¡Lluvia de popó!")
	M.rain(S, E.FeverRain)
end

-- auto = la recogió un perro: usa tu combo pero no lo sube (premia jugar activo)
local function applyPick(S, rec, auto)
	local steps = 1 + (rec.kind == "golden" and 2 or 0) + (rec.kind == "rainbow" and 9 or 0)
	local cb, f = S.combo, S.fever
	if not auto then
		cb.mult = math.min(E.ComboMax, cb.mult + E.ComboStep * steps)
		cb.last = os.clock()
		S.data.stats.maxCombo = math.max(S.data.stats.maxCombo, cb.mult)
	end
	f.value = math.min(E.FeverMax, f.value + E.FeverGain * steps * (auto and 0.5 or 1))
	if f.value >= E.FeverMax and not f.active then startFever(S) end

	local earned = math.round(rec.value * cb.mult * (f.active and E.FeverMult or 1) * State.boost(S, "poop"))
	State.addPoop(S, earned)
	S.data.stats.collected += 1
	Progress.gainXP(S, rec.kind == "rainbow" and H.XpRainbow or rec.kind == "golden" and H.XpGolden or H.XpPoop)
	if rec.kind == "rainbow" then State.notify(S, "¡¡POPÓ ARCOÍRIS!!", "banner", `+{earned} 💩`) end
	State.CollectedEv:FireClient(S.player, rec.pos, earned, rec.kind, cb.mult, auto)
end

function M.collect(S, rec, auto)
	if rec.done then return end
	rec.done = true
	rec.model:Destroy()
	S.poops[rec] = nil
	S.poopCount -= 1
	applyPick(S, rec, auto)
end

-- kind: normal | golden | rainbow. pos = punto en el suelo.
function M.spawn(S, pos, value, kind)
	if S.poopCount >= Data.POOP.MaxOnGround then return end
	value = math.round(value * Data.ZONES[S.data.park].mult) -- cada tipo de parque multiplica
	S.poopCount += 1

	local k = kind == "rainbow" and 1.7 or 1
	local model = Instance.new("Model")
	model.Name = "Caca"
	local d = 3 + 2 * State.upg(S, "magnet")
	local hitbox = Instance.new("Part")
	hitbox.Name = "Zona"
	hitbox.Size = Vector3.new(d, 4, d)
	hitbox.Position = pos + Vector3.new(0, 2, 0)
	hitbox.Transparency = 1
	hitbox.Anchored = true
	hitbox.CanCollide = false
	hitbox.CanQuery = false
	hitbox.Parent = model
	model.PrimaryPart = hitbox

	for i, size in { 1.8, 1.3, 0.8 } do
		local b = Instance.new("Part")
		b.Shape = Enum.PartType.Ball
		b.Size = Vector3.one * size * k
		b.Position = pos + Vector3.new(0, ({ 0.8, 1.55, 2.2 })[i] * k, 0)
		b.Anchored = true
		b.CanCollide, b.CanTouch, b.CanQuery = false, false, false
		if kind == "normal" then
			b.Color = Color3.fromRGB(105 - i * 8, 62 - i * 5, 30)
		else
			b.Material = Enum.Material.Neon
			b.Color = kind == "golden" and Color3.fromRGB(255, 205, 40) or Color3.fromHSV((i - 1) / 3, 0.7, 1)
		end
		b.Parent = model
	end
	if kind ~= "normal" then
		local fx = Instance.new("ParticleEmitter")
		fx.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		fx.Color = ColorSequence.new(Color3.fromRGB(255, 225, 90))
		fx.Rate = 10
		fx.Lifetime = NumberRange.new(1)
		fx.Speed = NumberRange.new(2, 4)
		fx.Parent = hitbox
	end
	model.Parent = S.folder
	for _, b in model:GetChildren() do -- cae desde arriba y rebota
		if b ~= hitbox then
			local goal = b.CFrame
			b.CFrame = goal + Vector3.new(0, 7, 0)
			TweenService:Create(b, TweenInfo.new(0.55, Enum.EasingStyle.Bounce), { CFrame = goal }):Play()
		end
	end

	local rec = { model = model, pos = pos, value = value, kind = kind }
	S.poops[rec] = true
	hitbox.Touched:Connect(function(hit)
		local char = hit:FindFirstAncestorWhichIsA("Model")
		if char and Players:GetPlayerFromCharacter(char) == S.player then M.collect(S, rec, false) end
	end)
	return rec
end

-- popó libre más cercana a pos dentro del radio
function M.nearestFree(S, pos, radius)
	local best, bd = nil, radius
	for rec in S.poops do
		local d = (rec.pos - pos).Magnitude
		if not rec.claimed and d < bd then best, bd = rec, d end
	end
	return best
end

local function rollKind(S, dog)
	if rng:NextNumber() < H.RainbowChance then return "rainbow" end
	if rng:NextNumber() < State.upg(S, "goldenchance") * tm(dog, "olfato", 1.2) * State.boost(S, "luck") * (1 + 0.2 * State.perk(S, "nose")) then return "golden" end
	return "normal"
end

function M.spawnFromDog(S, dog, at)
	local kind = rollKind(S, dog)
	local mult = kind == "rainbow" and H.RainbowMult or kind == "golden" and Data.POOP.GoldenMult or 1
	M.spawn(S, at, M.value(S, dog) * mult, kind)
end

-- lluvia de popó alrededor del jugador (fiebre)
function M.rain(S, n)
	local dogs = {}
	for _, id in S.data.active do table.insert(dogs, S.data.dogs[id]) end
	local char = S.player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if #dogs == 0 then return end
	local c = (hrp and Data.inYard(S.slot, hrp.Position, S.data.zones)) and hrp.Position or Data.yardCenter(S.slot)
	for _ = 1, n do
		task.delay(rng:NextNumber(0, 0.9), function()
			if S.dead then return end
			local dog = dogs[rng:NextInteger(1, #dogs)]
			local golden = rng:NextNumber() < 0.08
			local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(5, 26)
			local p = Data.clampToYard(S.slot, Vector3.new(c.X + math.cos(a) * r, 0, c.Z + math.sin(a) * r), S.data.zones)
			M.spawn(S, p, M.value(S, dog) * (golden and Data.POOP.GoldenMult or 1), golden and "golden" or "normal")
		end)
	end
end

function M.tick(S, dt)
	local cb, f = S.combo, S.fever
	local now = os.clock()
	if cb.mult > 1 and now - cb.last > E.ComboDecay then
		cb.mult = math.max(1, cb.mult - dt * (0.5 + (now - cb.last - E.ComboDecay) * 0.8))
		S.dirty = true
	end
	if f.active then
		if now >= f.untilT then f.active, f.value = false, 0 end
		S.dirty = true
	elseif f.value > 0 then
		f.value = math.max(0, f.value - E.FeverDecay * dt)
		S.dirty = true
	end
end

return M
