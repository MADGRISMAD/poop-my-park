-- Perros: creación aleatoria, activar/guardar, simulación (edad, hambre, felicidad, popó), platos y movimiento.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Shared.Data)
local State = require(script.Parent.State)
local Poop = require(script.Parent.Poop)

local DG = Data.DOG
local rng = Random.new()
local M = {}

local function rollWeighted(items, getW)
	local total = 0
	for _, it in items do total += getW(it) end
	local r = rng:NextNumber() * total
	for _, it in items do
		r -= getW(it)
		if r <= 0 then return it end
	end
	return items[#items]
end

local QUALITY_TABLE = {
	comun = { { "gris", 70 }, { "verde", 22 }, { "azul", 7 }, { "morado", 1 } },
	raro = { { "gris", 50 }, { "verde", 30 }, { "azul", 14 }, { "morado", 5 }, { "dorado", 1 } },
	epico = { { "gris", 25 }, { "verde", 35 }, { "azul", 25 }, { "morado", 12 }, { "dorado", 3 } },
	legend = { { "gris", 10 }, { "verde", 25 }, { "azul", 32 }, { "morado", 22 }, { "dorado", 9 }, { "rojo", 2 } },
	mitico = { { "verde", 20 }, { "azul", 30 }, { "morado", 28 }, { "dorado", 16 }, { "rojo", 5 }, { "cosmico", 1 } },
	cosmico = { { "azul", 15 }, { "morado", 30 }, { "dorado", 35 }, { "rojo", 15 }, { "cosmico", 5 } },
}
function M.rollQuality(rarity)
	return rollWeighted(QUALITY_TABLE[rarity], function(e) return e[2] end)[1]
end

local MAX_TRAITS = { comun = 1, raro = 2, epico = 3, legend = 4, mitico = 4, cosmico = 4 }

local function pick(list) return list[rng:NextInteger(1, #list)] end

local function rollTraits(rarity)
	local max = MAX_TRAITS[rarity]
	local n = math.min(max, rng:NextInteger(0, max))
	local out = {}
	for _ = 1, n do
		local r = rng:NextNumber()
		local kind
		if rarity == "cosmico" or rarity == "mitico" then kind = r < 0.55 and "pos" or r < 0.85 and "esp" or "neg"
		elseif rarity == "legend" then kind = r < 0.60 and "pos" or r < 0.80 and "esp" or "neg"
		elseif rarity == "epico" then kind = r < 0.55 and "pos" or r < 0.65 and "esp" or "neg"
		else kind = r < 0.50 and "pos" or "neg" end
		local t = pick(Data.TRAIT_POOL[kind])
		if not table.find(out, t) then table.insert(out, t) end
	end
	return out
end

-- weights: { rarityId = peso }; nil = pesos globales
function M.create(S, opts)
	opts = opts or {}
	local d = S.data
	local breed = opts.breed and Data.BREED[opts.breed]
	if not breed then
		local w = opts.weights
		-- la suerte (boost y fichas de renacer) sube todo lo que no es común
		local luck = (State.boost(S, "luck") > 1 and 1.5 or 1) * (1 + 0.1 * State.perk(S, "lucky"))
		if w and luck > 1 then
			w = table.clone(w)
			for k, v in w do
				if k ~= "comun" then w[k] = v * luck end
			end
		end
		local r = rollWeighted(Data.RARITIES, function(x) return w and (w[x.id] or 0) or x.weight end)
		local pool = {}
		for _, b in Data.BREEDS do
			if b.rarity == r.id then table.insert(pool, b) end
		end
		breed = pick(pool)
	end
	local j = function(b) return math.clamp(math.round(b + rng:NextNumber(-1, 1)), 1, 10) end
	local dog = {
		id = d.nextId, breed = breed.id, rarity = breed.rarity,
		quality = opts.quality or rollWeighted(QUALITY_TABLE[breed.rarity], function(e) return e[2] end)[1],
		sex = opts.sex or (rng:NextNumber() < 0.5 and "M" or "F"), traits = rollTraits(breed.rarity),
		age = opts.age or "baby", ageT = 0, level = 1, xp = 0,
		stats = { cago = j(breed.cago), come = j(breed.come), vel = j(breed.vel) },
		hunger = 80, happy = 80, mutations = opts.mutations or {}, size = opts.size or Data.rollSize(rng), fusion = 0,
	}
	local isNew = not d.discovered[breed.id]
	d.nextId += 1
	d.dogs[dog.id] = dog
	d.discovered[breed.id] = true
	S.dirty = true
	return dog, isNew
end

local function addXP(dog, n)
	if dog.level >= DG.MaxLevel then return end
	dog.xp += n
	while dog.level < DG.MaxLevel and dog.xp >= math.floor(DG.LevelXpBase * DG.LevelXpGrowth ^ (dog.level - 1)) do
		dog.xp -= math.floor(DG.LevelXpBase * DG.LevelXpGrowth ^ (dog.level - 1))
		dog.level += 1
		local k = pick({ "cago", "vel" })
		dog.stats[k] = math.min(10, dog.stats[k] + 1)
	end
end

-- platos --------------------------------------------------------------
local function bowlLabel(b) b.label.Text = `{Data.FOOD[b.type].icon} {b.qty}/{b.cap}` end

local function refill(S, bowl)
	local d = S.data
	local food = Data.FOOD[d.selectedFood]
	local cap = State.mods(S).bowlCap
	local room = cap - (bowl.type == food.id and bowl.qty or 0)
	if room <= 0 then return end
	local owned = d.food[food.id] or 0
	local amt = math.min(5, owned, room)
	if amt <= 0 then
		local cost = math.ceil(food.cost * State.mods(S).foodCost)
		if d.poop < cost then
			State.notify(S, `Necesitas {cost} 💩 para comprar comida`)
			return
		end
		d.poop -= cost
		d.food[food.id] = 1
		amt, owned = 1, 1
	end
	if bowl.type ~= food.id then bowl.type, bowl.qty = food.id, 0 end
	bowl.qty += amt
	bowl.cap = cap
	d.food[food.id] = owned - amt
	bowlLabel(bowl)
	S.dirty = true
end

function M.syncBowls(S)
	local m = State.mods(S)
	for i = #S.bowls, m.bowls + 1, -1 do -- tras renacer sobran platos
		S.bowls[i].part:Destroy()
		S.bowls[i] = nil
	end
	for i = 1, m.bowls do
		if not S.bowls[i] then
			local rel = Data.BowlRel[i]
			local pos = Data.yardRel(S.slot, rel[1], rel[2])
			local part = Instance.new("Part")
			part.Name = "Plato"
			part.Shape = Enum.PartType.Cylinder
			part.Size = Vector3.new(0.8, 4, 4)
			part.CFrame = CFrame.new(pos + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			part.Color = Color3.fromRGB(210, 120, 60)
			part.Anchored = true
			part.Parent = S.folder
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromOffset(120, 34)
			gui.StudsOffset = Vector3.new(0, 2.5, 0)
			gui.MaxDistance = 60
			gui.Parent = part
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.TextScaled = true
			label.Font = Enum.Font.FredokaOne
			label.TextColor3 = Color3.new(1, 1, 1)
			label.TextStrokeTransparency = 0
			label.Parent = gui
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Rellenar plato"
			prompt.ObjectText = "Plato"
			prompt.HoldDuration = 0.2
			prompt.MaxActivationDistance = 10
			prompt.Parent = part
			local bowl = { part = part, label = label, qty = 0, cap = m.bowlCap, type = "croquetas", pos = pos }
			prompt.Triggered:Connect(function(who)
				if who == S.player then refill(S, bowl) end
			end)
			S.bowls[i] = bowl
		end
		S.bowls[i].cap = m.bowlCap
		bowlLabel(S.bowls[i])
	end
end

local function feed(S, dog, run, bowl)
	local food = Data.FOOD[bowl.type]
	bowl.qty -= 1
	bowlLabel(bowl)
	dog.hunger = math.min(DG.MaxHunger, dog.hunger + food.hunger * (State.hasTrait(dog, "malcomedor") and 0.4 or 1))
	dog.happy = math.min(DG.MaxHappy, dog.happy + food.happy)
	local fx = food.fx and Data.FOOD_FX[food.fx]
	if fx then run.fx[fx[1]] = { mult = fx[2], untilT = os.clock() + fx[3] } end
	addXP(dog, DG.XpFeed)
end

-- seguir al jugador e ir por popó / comida ---------------------------------------
local function hrpOf(S)
	local char = S.player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

local function speedOf(S, dog, run)
	local fx = run.fx.speed
	local boost = fx and os.clock() < fx.untilT and fx.mult or 1
	return DG.MoveSpeed * 2.5 * Data.BREED[dog.breed].baseSpeed * (0.6 + dog.stats.vel / 12)
		* (dog.age == "baby" and 0.6 or 1) * Poop.traitMult(dog, "hiperactivo", 1.3)
		* Poop.traitMult(dog, "perezoso", 0.7) * State.mods(S).speed * boost
end

local function nearestBowl(S, pos, radius)
	local best, bd = nil, radius
	for _, b in S.bowls do
		local d = (b.pos - pos).Magnitude
		if b.qty > 0 and d < bd then best, bd = b, d end
	end
	return best
end

local function randomPoint(S)
	local h = Data.YARD.Half - 4
	return Data.yardRel(S.slot, rng:NextNumber(-h, h), rng:NextNumber(-h, h))
end

-- manda al perro a un punto del patio; los clientes lo animan con el mismo tiempo de viaje
local function sendTo(S, dog, run, pos, stay, onArrive)
	pos = Data.clampToYard(S.slot, pos, S.data.zones)
	local travel = math.clamp((pos - run.pos).Magnitude / speedOf(S, dog, run), 0.25, 5)
	run.busyUntil = os.clock() + travel + stay
	run.pos = pos
	State.PetTaskEv:FireAllClients(S.player.UserId, dog.id, pos, travel, stay)
	if onArrive then
		task.delay(travel + stay * 0.5, function()
			if not S.dead and run.alive then onArrive() end
		end)
	end
end

-- el perro va por la popó, la recoge con el hocico y te la entrega
local function fetch(S, dog, run, rec, hrp)
	rec.claimed = true
	local speed = speedOf(S, dog, run)
	local dest = Data.clampToYard(S.slot, hrp.Position, S.data.zones)
	local t1 = math.clamp((rec.pos - run.pos).Magnitude / speed, 0.25, 5)
	local t2 = math.clamp((dest - rec.pos).Magnitude / speed, 0.25, 5)
	local stay = Data.FETCH.Sniff
	run.busyUntil = os.clock() + t1 + stay + t2 + 0.4
	run.pos = dest
	State.PetTaskEv:FireAllClients(S.player.UserId, dog.id, rec.pos, t1, stay, t2)
	task.delay(t1 + stay * 0.6, function()
		if not rec.done then rec.model:Destroy() end -- ya va en el hocico
	end)
	task.delay(t1 + stay + t2, function()
		if not S.dead and run.alive then Poop.collect(S, rec, true) end
	end)
end

-- los perros pasean por el patio; si estás dentro, te traen la popó.
-- Con hambre no trabajan (van al plato si hay comida) y tras pelear quedan castigados un rato.
function M.assign(S)
	local hrp = hrpOf(S)
	local inside = hrp ~= nil and Data.inYard(S.slot, hrp.Position, S.data.zones)
	local now = os.clock()
	for id, run in S.run do
		local dog = S.data.dogs[id]
		if now >= run.busyUntil then
			local hungry = dog.hunger < DG.HungryAt
			local canWork = inside and dog.age ~= "baby" and not hungry and now >= (run.fightCd or 0)
			local bowl = hungry and nearestBowl(S, run.pos, 400)
			local rec = canWork and Poop.nearestFree(S, run.pos, math.huge)
			if bowl then
				sendTo(S, dog, run, bowl.pos, 1.2, function()
					if bowl.qty > 0 then feed(S, dog, run, bowl) end
				end)
			elseif rec then
				fetch(S, dog, run, rec, hrp)
			else
				sendTo(S, dog, run, randomPoint(S), rng:NextNumber(1.5, 5))
			end
		end
	end
end

-- peleas: dos perros cerca pueden pelearse; los infelices pelean más
function M.fights(S)
	local now = os.clock()
	local F = Data.FIGHT
	for id, run in S.run do
		local dog = S.data.dogs[id]
		local p = F.Chance * (Data.PELEA[dog.breed] or 5) / 5 * (dog.happy < 40 and 2 or 1)
		if dog.age ~= "baby" and now >= run.busyUntil and rng:NextNumber() < p then
			for otherId, other in S.run do
				local o = S.data.dogs[otherId]
				if otherId ~= id and o.age ~= "baby" and now >= other.busyUntil and (other.pos - run.pos).Magnitude < F.Range then
					local mid = (run.pos + other.pos) / 2
					for _, pair in { { dog, run, -1.5 }, { o, other, 1.5 } } do
						local r = pair[2]
						sendTo(S, pair[1], r, mid + Vector3.new(pair[3], 0, 0), F.Duration)
						r.fightCd = now + F.Duration + F.Cooldown
						pair[1].happy = math.max(0, pair[1].happy - F.HappyLoss)
					end
					State.FxEv:FireAllClients("fight", mid)
					State.notify(S, `💢 ¡{Data.BREED[dog.breed].name} y {Data.BREED[o.breed].name} se pelearon!`, "toast", `No recogerán popó por {F.Cooldown}s`)
					break
				end
			end
		end
	end
end

-- globo sobre el perro: 🍖 con hambre, 💢 castigado por pelear
function M.moods(S)
	local now = os.clock()
	local folder = State.PetsFolder:FindFirstChild(tostring(S.player.UserId))
	if not folder then return end
	for id, run in S.run do
		local dog = S.data.dogs[id]
		local mood = now < (run.fightCd or 0) and "💢" or dog.hunger < DG.HungryAt and "🍖" or ""
		if mood ~= run.mood then
			run.mood = mood
			local cfg = folder:FindFirstChild(tostring(id))
			if cfg then cfg:SetAttribute("mood", mood) end
		end
	end
end

-- activar / guardar -------------------------------------------------------
local function petFolder(S)
	local f = State.PetsFolder:FindFirstChild(tostring(S.player.UserId))
	if not f then
		f = Instance.new("Folder")
		f.Name = tostring(S.player.UserId)
		f.Parent = State.PetsFolder
	end
	return f
end

local function syncPet(S, dog)
	local cfg = petFolder(S):FindFirstChild(tostring(dog.id)) or Instance.new("Configuration")
	cfg.Name = tostring(dog.id)
	for _, k in { "breed", "rarity", "quality", "age" } do cfg:SetAttribute(k, dog[k]) end
	cfg:SetAttribute("size", dog.size or 1)
	cfg:SetAttribute("fusion", dog.fusion or 0)
	cfg:SetAttribute("mutations", table.concat(dog.mutations or {}, ","))
	local run = S.run[dog.id]
	if run and not cfg.Parent then
		cfg:SetAttribute("x", run.pos.X)
		cfg:SetAttribute("z", run.pos.Z)
	end
	cfg.Parent = petFolder(S)
end

-- aplica una mutación (si procede) y lo celebra; devuelve true si cambió
function M.mutate(S, dog, id)
	local list = Data.applyMutation(dog.mutations, id)
	if not list then return false end
	dog.mutations = list
	S.data.stats.mutations += 1
	local newest = list[#list]
	local mu = Data.MUTATIONS[newest]
	local breed = Data.BREED[dog.breed]
	syncPet(S, dog)
	local run = S.run[dog.id]
	if run then State.FxEv:FireAllClients("mutate", run.pos, newest) end
	State.notify(S, `¡{breed.name} ahora es {string.upper(mu.name)}! {mu.icon}`, "toast", `x{Data.mutationMult(list)} popó`)
	if mu.mult >= 8 then
		State.AnnounceEv:FireAllClients(`¡El {breed.name} de {S.player.DisplayName} mutó a {mu.name}! {mu.icon}`, mu.color)
	end
	S.dirty = true
	return true
end

function M.activate(S, id)
	local d = S.data
	local dog = d.dogs[id]
	if not dog or S.run[id] or #d.active >= State.capacity(S) then return false end
	table.insert(d.active, id)
	S.run[id] = { alive = true, poopT = 0, nextPoop = 3, fx = {}, busyUntil = 0, pos = randomPoint(S) }
	syncPet(S, dog)
	S.dirty = true
	return true
end

function M.deactivate(S, id)
	local run = S.run[id]
	if not run then return false end
	run.alive = false
	S.run[id] = nil
	table.remove(S.data.active, table.find(S.data.active, id))
	local cfg = petFolder(S):FindFirstChild(tostring(id))
	if cfg then cfg:Destroy() end
	S.dirty = true
	return true
end

-- equipa a los que más producen
function M.equipBest(S)
	local list = {}
	for _, dog in S.data.dogs do table.insert(list, dog) end
	local function score(dog)
		return Data.BREED[dog.breed].produce * Data.RARITY[dog.rarity].mult * Data.QUALITY[dog.quality].mult
			* DG.AgeMult[dog.age] * (1 + (dog.level - 1) * DG.LevelProdBonus)
	end
	table.sort(list, function(a, b) return score(a) > score(b) end)
	for _, id in table.clone(S.data.active) do M.deactivate(S, id) end
	for i = 1, math.min(#list, State.capacity(S)) do M.activate(S, list[i].id) end
end

-- fusiona 3+ perros de la misma raza y nivel de fusión en uno de nivel +1
function M.fuse(S, ids)
	local d = S.data
	if typeof(ids) ~= "table" or #ids < Data.FUSION.Need then return { ok = false, msg = `Elige al menos {Data.FUSION.Need} perros` } end
	local dogs, seen = {}, {}
	for _, id in ids do
		local dog = typeof(id) == "number" and d.dogs[id]
		if not dog or seen[id] then return { ok = false } end
		seen[id] = true
		table.insert(dogs, dog)
	end
	local first = dogs[1]
	local f = first.fusion or 0
	if f >= Data.FUSION.Max then return { ok = false, msg = "Ese perro ya está al máximo de fusión" } end
	for _, dog in dogs do
		if dog.breed ~= first.breed or (dog.fusion or 0) ~= f then
			return { ok = false, msg = "Deben ser de la misma raza y el mismo nivel de fusión" }
		end
	end
	local wasActive, size, level, quality, muts, traits = false, 0, 1, first.quality, {}, {}
	for _, dog in dogs do
		wasActive = wasActive or S.run[dog.id] ~= nil
		M.deactivate(S, dog.id)
		size += dog.size or 1
		level = math.max(level, dog.level)
		if Data.QUALITY_IDX[dog.quality] > Data.QUALITY_IDX[quality] then quality = dog.quality end
		for _, m in dog.mutations or {} do muts = Data.applyMutation(muts, m) or muts end
		for _, t in dog.traits do
			if #traits < 4 and not table.find(traits, t) then table.insert(traits, t) end
		end
	end
	for i = 2, #dogs do d.dogs[dogs[i].id] = nil end
	first.size = math.round(size / #dogs * 100) / 100
	first.fusion, first.level, first.quality, first.mutations, first.traits = f + 1, level, quality, muts, traits
	first.age, first.ageT = "adult", 0
	d.stats.fusions += 1
	if wasActive then M.activate(S, first.id) end
	if f + 1 >= 3 then
		State.AnnounceEv:FireAllClients(`¡{S.player.DisplayName} fusionó un {Data.BREED[first.breed].name} {Data.FUSION.Stars[f + 1]}!`, Data.RARITY[first.rarity].color)
	end
	S.dirty = true
	return { ok = true, dog = State.dogInfo(S, first) }
end

function M.removePets(S)
	local f = State.PetsFolder:FindFirstChild(tostring(S.player.UserId))
	if f then f:Destroy() end
end

-- simulación ---------------------------------------------------------------
local function ageTick(dog, dt)
	dog.ageT += dt
	local a = dog.age
	if a == "baby" and dog.ageT >= DG.AgeBaby then dog.age, dog.ageT = "young", 0
	elseif a == "young" and dog.ageT >= DG.AgeYoung then dog.age, dog.ageT = "adult", 0
	elseif a == "adult" and dog.ageT >= DG.AgeVeteran then dog.age, dog.ageT = "veteran", 0 end
	return dog.age ~= a
end

local function poopInterval(S, dog, run)
	local breed = Data.BREED[dog.breed]
	local statCago = 0.6 + dog.stats.cago / 12
	local rate = breed.produce * Data.RARITY[dog.rarity].mult * Data.QUALITY[dog.quality].mult * statCago
	local fx = run.fx.prod
	local denom = rate * DG.AgeMult[dog.age] * (0.5 + dog.happy / 200) * (dog.hunger > 30 and 1 or 0.4)
		* Poop.traitMult(dog, "productor", 1.25) * Poop.traitMult(dog, "perezoso", 0.7)
		* (1 + (dog.level - 1) * DG.LevelProdBonus) * (fx and os.clock() < fx.untilT and fx.mult or 1)
		* State.upg(S, "production") * State.mods(S).prod
	return math.max(0.8, (DG.PoopBase + rng:NextNumber() * DG.PoopVar) / math.max(denom, 0.001))
end

function M.tick(S, dt)
	for _, dog in S.data.dogs do
		local changed = ageTick(dog, dt)
		local run = S.run[dog.id]
		if run then
			if changed then syncPet(S, dog) end
			local comeF = 0.6 + dog.stats.come / 20
			dog.hunger = math.max(0, dog.hunger - DG.HungerDecay * dt * Poop.traitMult(dog, "estomago", 0.75)
				* Poop.traitMult(dog, "gloton", 1.5) * comeF * State.upg(S, "hunger"))
			dog.happy = math.max(0, dog.happy - DG.HappyDecay * dt * Poop.traitMult(dog, "felizpornat", 0.6)
				* State.upg(S, "happy"))
			if S.poopCount > 30 then
				dog.happy = math.max(0, dog.happy - 0.4 * dt * S.poopCount / 30)
			end
			if dog.age ~= "baby" then
				run.poopT += dt
				if run.poopT >= run.nextPoop then
					run.poopT = 0
					run.nextPoop = poopInterval(S, dog, run)
					local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(2, 5)
					Poop.spawnFromDog(S, dog, Data.clampToYard(S.slot, run.pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), S.data.zones))
					addXP(dog, DG.XpPoop)
				end
			end
		end
	end
	S.dirty = true
end

return M
