-- Datos de cada jugador: carga/guardado (DataStore), remotes y snapshot para el cliente.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage.Shared.Data)

-- en un place sin publicar GetDataStore falla: jugamos sin guardar
local okStore, store = pcall(DataStoreService.GetDataStore, DataStoreService, "PopoPark_v1")
if not okStore then warn("DataStore no disponible (publica el place para guardar):", store) end
local M = { sessions = {} }

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage
local function remote(class, name)
	local r = Instance.new(class)
	r.Name = name
	r.Parent = remotes
	return r
end
M.Do = remote("RemoteFunction", "Do") -- cliente -> servidor (acciones)
M.StateEv = remote("RemoteEvent", "State") -- servidor -> cliente (snapshot)
M.NotifyEv = remote("RemoteEvent", "Notify") -- servidor -> cliente (avisos)
M.UIEv = remote("RemoteEvent", "OpenUI") -- servidor -> cliente (abrir pestaña)
M.CollectedEv = remote("RemoteEvent", "Collected") -- servidor -> dueño (efectos al recoger)
M.PetTaskEv = remote("RemoteEvent", "PetTask") -- servidor -> todos (un perro va a un punto)
M.AnnounceEv = remote("RemoteEvent", "Announce") -- servidor -> todos (perro raro)
M.FxEv = remote("RemoteEvent", "Fx") -- servidor -> todos (rayos, meteoritos, mutaciones)

-- perros equipados de cada jugador; los clientes los dibujan y animan
M.PetsFolder = Instance.new("Folder")
M.PetsFolder.Name = "Pets"
M.PetsFolder.Parent = ReplicatedStorage

local function defaults()
	return {
		poop = Data.ECONOMY.StartPoop, packs = table.clone(Data.ECONOMY.StartPacks),
		food = {}, upgrades = {}, objects = {}, dogs = {}, nextId = 1, active = {},
		level = 1, xp = 0, mission = 1, selectedFood = "croquetas", discovered = {},
		stats = { totalPoop = 0, collected = 0, packs = 0, fever = 0, maxCombo = 1, mutations = 0, fusions = 0 },
		quests = { day = 0, base = {}, claimed = {} }, indexClaimed = {},
		zones = 1, rebirths = 0, daily = { last = 0, streak = 0 }, boosts = {}, codes = {},
		items = {}, gear = {}, park = 1, tokens = 0, perks = {},
	}
end

-- devuelve data, esNueva, sePuedeGuardar
function M.load(player)
	if not okStore then
		local d = defaults()
		d.dogs = {}
		return d, true, false
	end
	local ok, saved = pcall(store.GetAsync, store, "u_" .. player.UserId)
	if not ok then
		warn("No se pudo cargar:", saved)
		saved = nil
	end
	local d = saved or defaults()
	local def = defaults()
	for k, v in def do
		if d[k] == nil then d[k] = v end
	end
	for k, v in def.stats do -- contadores nuevos en partidas viejas
		if d.stats[k] == nil then d.stats[k] = v end
	end
	local map = {}
	for _, dog in d.dogList or {} do map[dog.id] = dog end
	d.dogs, d.dogList = map, nil
	return d, saved == nil, ok
end

function M.save(S)
	if not okStore or not S.canSave then return end
	local payload = table.clone(S.data)
	local list = {}
	for _, dog in S.data.dogs do table.insert(list, dog) end
	payload.dogs, payload.dogList, payload.lastSaved = nil, list, os.time()
	local ok, err = pcall(store.SetAsync, store, "u_" .. S.player.UserId, payload)
	if not ok then warn("No se pudo guardar:", err) end
end

function M.notify(S, text, kind, sub)
	M.NotifyEv:FireClient(S.player, text, kind or "toast", sub)
end

function M.addPoop(S, n)
	S.data.poop += n
	S.data.stats.totalPoop += n
	S.dirty = true
end

local function count(t, id) return t[id] or 0 end
function M.capacity(S)
	return Data.DOG.CapacityBase + 2 * count(S.data.objects, "cap_basic") + 4 * count(S.data.objects, "cap_pro")
		+ count(S.data.perks, "leash")
end
function M.mods(S)
	local o = S.data.objects
	return {
		prod = 1 + 0.10 * count(o, "gold_statue"), speed = 1 + 0.10 * count(o, "agility"),
		foodCost = 1 - 0.25 * count(o, "chef_perruno"), bowlCap = 10 + 5 * count(o, "bowl_capacity"),
		bowls = math.min(#Data.BowlRel, 2 + count(o, "bowl_extra")),
	}
end
function M.upg(S, id) return Data.UPGRADE[id].effect(S.data.upgrades[id] or 0) end
function M.perk(S, id) return S.data.perks[id] or 0 end
function M.boostLeft(S, id) return math.max(0, (S.data.boosts[id] or 0) - os.time()) end
function M.boost(S, id) return M.boostLeft(S, id) > 0 and 2 or 1 end
function M.hasTrait(dog, id) return table.find(dog.traits, id) ~= nil end

function M.dogInfo(S, dog)
	return {
		id = dog.id, breed = dog.breed, rarity = dog.rarity, quality = dog.quality, sex = dog.sex,
		traits = dog.traits, age = dog.age, level = dog.level, mutations = dog.mutations or {},
		size = dog.size or 1, fusion = dog.fusion or 0,
		hunger = math.floor(dog.hunger), happy = math.floor(dog.happy), active = S.run[dog.id] ~= nil,
	}
end

function M.snapshot(S)
	local d = S.data
	local dogs = {}
	for _, dog in d.dogs do table.insert(dogs, M.dogInfo(S, dog)) end
	local m = Data.MISSIONS[d.mission]
	local Progress = require(script.Parent.Progress)
	local snap = {
		poop = d.poop, packs = d.packs, food = d.food, upgrades = d.upgrades, objects = d.objects,
		capacity = M.capacity(S), level = d.level, xp = d.xp, xpNext = Progress.xpFor(d.level),
		combo = S.combo.mult, fever = S.fever.value, feverActive = S.fever.active,
		selectedFood = d.selectedFood, dogs = dogs, activeCount = #d.active,
		mission = m and { title = m.title, desc = m.desc, progress = S.mProg, target = m.target } or nil,
		foodCostMult = M.mods(S).foodCost,
	}
	for k, v in require(script.Parent.Meta).snapshot(S) do snap[k] = v end
	snap.items, snap.stock, snap.gearPlaced = d.items, require(script.Parent.Gear).stockFor(S), #S.gear
	return snap
end

return M
