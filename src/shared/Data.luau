-- Datos del juego, portados de popo2 (js/config.js y js/data/*.js)
local c = Color3.fromHex
local D = {}

D.ECONOMY = {
	StartPoop = 50, StartPacks = { food = 1, dog = 1, legend = 0 },
	ComboDecay = 2.4, ComboStep = 0.08, ComboMax = 10,
	FeverMax = 100, FeverDecay = 1.2, FeverGain = 2.2, FeverDuration = 14, FeverMult = 2, FeverRain = 18,
}
D.DOG = {
	MaxHunger = 100, MaxHappy = 100, HungerDecay = 0.8, HappyDecay = 0.12,
	AgeBaby = 60, AgeYoung = 180, AgeVeteran = 1800,
	AgeMult = { baby = 0.2, young = 0.6, adult = 1, veteran = 0.85 },
	AgeScale = { baby = 0.55, young = 0.8, adult = 1, veteran = 1 },
	PoopBase = 2.6, PoopVar = 1.8, HungryAt = 35, CapacityBase = 6,
	LevelXpBase = 50, LevelXpGrowth = 1.35, LevelProdBonus = 0.04, MaxLevel = 50,
	XpPoop = 1, XpFeed = 4, MoveSpeed = 6, -- studs/s
}
-- los perros equipados te siguen y van solos por la popó cercana
D.FETCH = { Radius = 22, PerMagnet = 2, Sniff = 0.45 }
-- sonidos: cambia por IDs del Creator Store ("rbxassetid://123...") para un acabado pro
D.SOUNDS = {
	pick = "rbxasset://sounds/volume_slider.ogg",
	gold = "rbxasset://sounds/action_jump_land.mp3",
	hatch = "rbxasset://sounds/impact_explosion_03.mp3",
	click = "rbxasset://sounds/volume_slider.ogg",
}
D.POOP = { GoldenChance = 0.05, GoldenMult = 8, MaxOnGround = 80 }
D.HOOKS = {
	XpBase = 25, XpGrowth = 1.22, XpPoop = 1, XpGolden = 6, XpRainbow = 40, XpPack = 4,
	RainbowChance = 0.004, RainbowMult = 60,
}

-- Parcelas: 8 patios, 4 a cada lado de la calle central (como Grow a Garden).
-- Coordenadas relativas: x = izquierda/derecha, z = hacia el fondo (lejos de la calle).
D.SLOTS = 8
D.YARD = { Half = 40, Road = 20 }
D.BowlRel = { { -12, -15 }, { 12, -15 }, { -12, 12 }, { 12, 12 }, { 0, -28 }, { 0, 28 }, { -30, -10 }, { 30, -10 } }
function D.slotSide(slot) return slot <= 4 and 1 or -1 end
function D.yardCenter(slot)
	return Vector3.new(((slot - 1) % 4 - 1.5) * 100, 0, D.slotSide(slot) * (D.YARD.Road + D.YARD.Half))
end
function D.yardRel(slot, x, z) return D.yardCenter(slot) + Vector3.new(x, 0, z * D.slotSide(slot)) end
function D.inYard(slot, pos, _, margin)
	local c, h = D.yardCenter(slot), D.YARD.Half - (margin or 0)
	return math.abs(pos.X - c.X) <= h and math.abs(pos.Z - c.Z) <= h
end
function D.clampToYard(slot, pos, _, margin)
	local c, h = D.yardCenter(slot), D.YARD.Half - (margin or 3)
	return Vector3.new(math.clamp(pos.X, c.X - h, c.X + h), 0, math.clamp(pos.Z, c.Z - h, c.Z + h))
end

-- Tipos de parque: mismo cuadrado, otro lugar. Se desbloquean en orden y eliges cuál usar.
-- bias = la mutación de ese lugar sale más seguido
D.ZONES = {
	{ name = "Parque", icon = "🌳", mult = 1, cost = 0, color = Color3.fromRGB(120, 190, 90), material = Enum.Material.Grass, bias = {} },
	{ name = "Playa", icon = "🏖️", mult = 2.5, cost = 10000, color = Color3.fromRGB(240, 215, 150), material = Enum.Material.Sand, bias = { mojado = 2 } },
	{ name = "Nieve", icon = "❄️", mult = 6, cost = 250000, color = Color3.fromRGB(235, 245, 255), material = Enum.Material.Snow, bias = { congelado = 2 } },
	{ name = "Desierto", icon = "🌵", mult = 15, cost = 4e6, color = Color3.fromRGB(225, 170, 95), material = Enum.Material.Sand, bias = { dorado = 2 } },
	{ name = "Volcán", icon = "🌋", mult = 40, cost = 5e7, color = Color3.fromRGB(60, 45, 45), material = Enum.Material.Basalt, bias = { electrificado = 2 } },
	{ name = "Dulces", icon = "🍭", mult = 100, cost = 6e8, color = Color3.fromRGB(255, 170, 210), material = Enum.Material.SmoothPlastic, bias = { arcoiris = 2 } },
	{ name = "Espacio", icon = "🪐", mult = 250, cost = 8e9, color = Color3.fromRGB(45, 40, 70), material = Enum.Material.Slate, bias = { cosmico = 2 } },
	{ name = "Cielo", icon = "☁️", mult = 600, cost = 1e11, color = Color3.fromRGB(245, 248, 255), material = Enum.Material.SmoothPlastic, bias = { dorado = 3, arcoiris = 2 } },
}

-- Renacer: reinicia la economía a cambio de un multiplicador permanente
D.REBIRTH = { BaseCost = 100000, Growth = 4, MultPer = 0.5 }
function D.rebirthCost(r) return math.floor(D.REBIRTH.BaseCost * D.REBIRTH.Growth ^ r) end
function D.rebirthMult(r) return 1 + r * D.REBIRTH.MultPer end
function D.rebirthTokens(r) return 1 + r // 5 end -- fichas que da el renacimiento número r+1

-- Tienda de renacer: mejoras permanentes pagadas con fichas 🔄
D.PERKS = {
	{ id = "leash", name = "Correa extra", icon = "🦮", desc = "+1 perro equipado.", max = 6, cost = function(l) return 1 + l end },
	{ id = "bags", name = "Bolsas de oro", icon = "💰", desc = "+25% valor de toda la popó.", max = 20, cost = function(l) return 1 + l // 2 end },
	{ id = "nose", name = "Súper olfato", icon = "👃", desc = "+20% popós doradas.", max = 10, cost = function(l) return 1 + l // 2 end },
	{ id = "lucky", name = "Suerte de sobre", icon = "🍀", desc = "+10% rarezas altas en sobres.", max = 10, cost = function(l) return 2 + l end },
	{ id = "storm", name = "Imán de clima", icon = "🌩️", desc = "+15% probabilidad de mutar.", max = 10, cost = function(l) return 2 + l end },
}
D.PERK = {}
for _, p in D.PERKS do D.PERK[p.id] = p end

-- Recompensas: { poop, packs = { id = n }, boost = "poop"|"luck", min }
D.BOOSTS = { poop = { name = "x2 Popó", icon = "💩" }, luck = { name = "x2 Suerte", icon = "🍀" } }
D.DAILY = {
	{ poop = 150 }, { packs = { food = 2 } }, { poop = 500 }, { packs = { dog = 1 } },
	{ boost = "poop", min = 15 }, { packs = { dog = 2 } }, { packs = { legend = 1 } },
}
D.GIFTS = { -- segundos jugados en la sesión
	{ t = 60, poop = 100 }, { t = 180, packs = { food = 1 } }, { t = 300, boost = "luck", min = 5 },
	{ t = 600, packs = { dog = 1 } }, { t = 900, poop = 1000 }, { t = 1200, boost = "poop", min = 10 },
	{ t = 1800, packs = { dog = 2 } }, { t = 2700, poop = 5000 }, { t = 3600, packs = { legend = 1 } },
}
function D.scalePoop(poop, level) return math.floor(poop * (1 + (level - 1) * 0.15)) end
function D.rewardIcon(r)
	if r.poop then return "💩" end
	if r.boost then return D.BOOSTS[r.boost].icon end
	local id = next(r.packs)
	return D.PACK[id].icon
end
function D.rewardText(r, level)
	if r.poop then return `{D.scalePoop(r.poop, level)} Popó` end
	if r.boost then return `{D.BOOSTS[r.boost].name} {r.min} min` end
	local id, n = next(r.packs)
	return `{n}x {D.PACK[id].name}`
end

-- Mutaciones permanentes de los perros (multiplican su popó). mult se suma: 1 + Σ(mult - 1)
D.MUTATIONS = {
	mojado = { name = "Mojado", icon = "💧", mult = 2, color = Color3.fromRGB(90, 170, 255) },
	congelado = { name = "Congelado", icon = "❄️", mult = 3, color = Color3.fromRGB(170, 230, 255) },
	electrificado = { name = "Electrificado", icon = "⚡", mult = 5, color = Color3.fromRGB(255, 230, 60) },
	arcoiris = { name = "Arcoíris", icon = "🌈", mult = 8, color = Color3.fromRGB(255, 120, 200) },
	helado = { name = "Helado", icon = "🧊", mult = 10, color = Color3.fromRGB(120, 200, 255) },
	dorado = { name = "Dorado", icon = "✨", mult = 20, color = Color3.fromRGB(255, 200, 40) },
	cosmico = { name = "Cósmico", icon = "🌌", mult = 30, color = Color3.fromRGB(160, 90, 255) },
}
D.MUTATION_ORDER = { "mojado", "congelado", "electrificado", "arcoiris", "helado", "dorado", "cosmico" }
D.MUTATION_COMBOS = { { "mojado", "congelado", "helado" } } -- a + b = resultado (reemplaza a ambas)
D.GOLDEN_PASSIVE = 0.00003 -- probabilidad/seg de volverse Dorado en cualquier momento

function D.mutationMult(list)
	local m = 1
	for _, id in list or {} do m += D.MUTATIONS[id].mult - 1 end
	return m
end
-- devuelve la nueva lista o nil si no cambia
function D.applyMutation(list, id)
	list = list or {}
	if table.find(list, id) then return nil end
	if table.find(list, "helado") and (id == "mojado" or id == "congelado") then return nil end
	local out = table.clone(list)
	table.insert(out, id)
	for _, combo in D.MUTATION_COMBOS do
		local a, b = table.find(out, combo[1]), table.find(out, combo[2])
		if a and b then
			table.remove(out, math.max(a, b))
			table.remove(out, math.min(a, b))
			table.insert(out, combo[3])
		end
	end
	return out
end
function D.mutationIcons(list)
	local s = ""
	for _, id in list or {} do s ..= D.MUTATIONS[id].icon end
	return s
end

-- Clima global: mut = probabilidad/seg de cada mutación para perros en el patio
D.WEATHER_GAP = { 150, 270 }
D.WEATHERS = {
	lluvia = { name = "Lluvia", icon = "🌧️", weight = 40, dur = { 60, 100 }, mut = { mojado = 0.004 }, desc = "Tus perros pueden quedar MOJADOS 💧" },
	tormenta = { name = "Tormenta", icon = "⛈️", weight = 18, dur = { 50, 80 }, mut = { mojado = 0.003, electrificado = 0.0015 }, desc = "¡Los rayos ELECTRIFICAN perros! ⚡" },
	nevada = { name = "Nevada", icon = "🌨️", weight = 25, dur = { 60, 100 }, mut = { congelado = 0.0035 }, desc = "Tus perros pueden quedar CONGELADOS ❄️" },
	arcoiris = { name = "Arcoíris", icon = "🌈", weight = 12, dur = { 45, 70 }, mut = { arcoiris = 0.0012 }, desc = "Mutación ARCOÍRIS posible 🌈" },
	meteoritos = { name = "Lluvia de meteoritos", icon = "☄️", weight = 5, dur = { 40, 60 }, mut = {}, desc = "¡Los meteoritos vuelven CÓSMICOS a los perros! 🌌" },
}

-- Equipo colocable en tu patio: sube la probabilidad de su mutación a los perros cercanos
D.GEAR = {
	-- dur = segundos que dura colocado; después se gasta
	aspersor = { name = "Aspersor", icon = "💦", mut = "mojado", radius = 18, boost = 3, passive = 0.0015, dur = 600, desc = "Moja perros cercanos. x3 en lluvia. Dura 10 min." },
	pararrayos = { name = "Pararrayos", icon = "🗼", mut = "electrificado", radius = 22, boost = 4, passive = 0, dur = 600, desc = "Atrae rayos en tormenta. x4. Dura 10 min." },
	congelador = { name = "Congelador", icon = "🧊", mut = "congelado", radius = 18, boost = 3, passive = 0.001, dur = 600, desc = "Congela perros cercanos. x3 en nevada. Dura 10 min." },
	prisma = { name = "Prisma", icon = "🔮", mut = "arcoiris", radius = 16, boost = 3, passive = 0.0003, dur = 480, desc = "Arcoíris cerca de él. x3 con arcoíris. Dura 8 min." },
	antena = { name = "Antena cósmica", icon = "📡", mut = "cosmico", radius = 16, boost = 3, passive = 0.0001, dur = 360, desc = "Atrae meteoritos y lo cósmico. Dura 6 min." },
}
D.MAX_GEAR = 6
-- Sprays: se usan sobre un perro desde su ficha
D.SPRAYS = {
	spray_mojado = { name = "Spray Mojado", icon = "🧴", mut = "mojado", chance = 1, desc = "100% Mojado." },
	spray_arcoiris = { name = "Spray Arcoíris", icon = "🌈", mut = "arcoiris", chance = 0.25, desc = "25% Arcoíris." },
	spray_dorado = { name = "Spray Dorado", icon = "✨", mut = "dorado", chance = 0.3, desc = "30% Dorado." },
}
-- Tienda que se reabastece: chance de aparecer en cada reabastecimiento y stock
D.RESTOCK = 300
D.SHOP = {
	{ id = "aspersor", cost = 1500, chance = 0.9, stock = { 1, 3 } },
	{ id = "spray_mojado", cost = 800, chance = 0.8, stock = { 1, 5 } },
	{ id = "pararrayos", cost = 12000, chance = 0.5, stock = { 1, 2 } },
	{ id = "congelador", cost = 25000, chance = 0.4, stock = { 1, 2 } },
	{ id = "spray_arcoiris", cost = 40000, chance = 0.2, stock = { 1, 2 } },
	{ id = "spray_dorado", cost = 60000, chance = 0.12, stock = { 1, 1 } },
	{ id = "prisma", cost = 150000, chance = 0.15, stock = { 1, 1 } },
	{ id = "antena", cost = 800000, chance = 0.06, stock = { 1, 1 } },
}
function D.item(id) return D.GEAR[id] or D.SPRAYS[id] end

-- Tamaño: cada perro nace con uno; más grande = más popó (valor x tamaño)
function D.rollSize(rng)
	local r = rng:NextNumber()
	if r < 0.05 then return math.round(rng:NextNumber(0.5, 0.7) * 100) / 100 end -- mini
	if r > 0.95 then return math.round(rng:NextNumber(1.4, 1.9) * 100) / 100 end -- gigante
	return math.round(rng:NextNumber(0.75, 1.25) * 100) / 100
end
function D.sizeLabel(s)
	s = s or 1
	if s < 0.72 then return "Mini" elseif s < 0.9 then return "Pequeño" elseif s <= 1.15 then return "Normal"
	elseif s <= 1.4 then return "Grande" end
	return "Gigante"
end

-- Fusión: 3+ perros de la misma raza y nivel -> uno de nivel +1 (tamaño promedio, suma de mutaciones)
D.FUSION = { Need = 3, Max = 5, Mult = { 2.5, 6, 14, 30, 65 }, Stars = { "★", "★★", "★★★", "✦✦✦✦", "👑" } }
function D.fusionMult(f) return (f or 0) > 0 and D.FUSION.Mult[f] or 1 end

-- Retos diarios: los mismos 3 para todo el servidor cada día
D.QUESTS = {
	{ type = "collected", target = 300, title = "Recoge 300 popós", reward = { poop = 800 } },
	{ type = "collected", target = 1000, title = "Recoge 1,000 popós", reward = { packs = { dog = 2 } } },
	{ type = "packs", target = 5, title = "Abre 5 sobres", reward = { poop = 1500 } },
	{ type = "packs", target = 15, title = "Abre 15 sobres", reward = { packs = { legend = 1 } } },
	{ type = "mutations", target = 2, title = "Consigue 2 mutaciones", reward = { boost = "luck", min = 20 } },
	{ type = "fusions", target = 1, title = "Fusiona perros 1 vez", reward = { packs = { dog = 3 } } },
	{ type = "fusions", target = 3, title = "Fusiona perros 3 veces", reward = { boost = "poop", min = 20 } },
	{ type = "fever", target = 3, title = "Activa 3 fiebres", reward = { poop = 2500 } },
}
D.QUEST_BONUS = { packs = { legend = 1 } } -- por completar los 3
-- Índice: premios por descubrir razas
D.INDEX_REWARDS = {
	{ n = 5, reward = { packs = { dog = 2 } } }, { n = 10, reward = { packs = { legend = 1 } } },
	{ n = 15, reward = { packs = { legend = 3 } } }, { n = 20, reward = { packs = { mitico = 1 } } },
	{ n = 23, reward = { packs = { cosmico = 1 } } },
}
-- Peleas: peleonería por raza (1-10). Un perro peleado no recoge popó durante Cooldown segundos.
D.FIGHT = { Chance = 0.004, Range = 12, Duration = 3, Cooldown = 25, HappyLoss = 10 }
D.PELEA = { callejero = 6, beagle = 4, labrador = 3, pug = 3, chihuahua = 8, bulldog = 7, corgi = 4, poodle = 3,
	husky = 5, pastor = 5, dalmata = 4, border = 3, golden = 2, gran_danes = 5, shiba = 4, akita = 5, samoyedo = 2,
	aurodog = 3, lobo = 7, mecanico = 4, fenrir = 8, cerbero = 9, estelar = 1 }

D.FRIEND_BONUS = 0.1 -- +10% de popó por amigo en el servidor (máx 5)

D.RARITIES = {
	{ id = "comun", name = "Común", weight = 1000, mult = 1.0, color = c("#cfd3d8") },
	{ id = "raro", name = "Raro", weight = 300, mult = 1.6, color = c("#4aa3ff") },
	{ id = "epico", name = "Épico", weight = 90, mult = 2.5, color = c("#b061ff") },
	{ id = "legend", name = "Legendario", weight = 22, mult = 4.5, color = c("#ffc93c") },
	{ id = "mitico", name = "Mítico", weight = 6, mult = 8.0, color = c("#ff4d4d") },
	{ id = "cosmico", name = "Cósmico", weight = 1, mult = 16.0, color = c("#ff5fd0") },
}
D.QUALITIES = {
	{ id = "gris", name = "Gris", mult = 1.00, color = c("#9aa0a6") },
	{ id = "verde", name = "Verde", mult = 1.10, color = c("#4ade80") },
	{ id = "azul", name = "Azul", mult = 1.25, color = c("#3b82f6") },
	{ id = "morado", name = "Morado", mult = 1.45, color = c("#a855f7") },
	{ id = "dorado", name = "Dorado", mult = 1.75, color = c("#facc15") },
	{ id = "rojo", name = "Rojo", mult = 2.10, color = c("#ef4444") },
	{ id = "cosmico", name = "Cósmico", mult = 2.75, color = c("#22d3ee") },
}
D.RARITY, D.QUALITY, D.RARITY_IDX, D.QUALITY_IDX = {}, {}, {}, {}
for i, r in D.RARITIES do D.RARITY[r.id] = r; D.RARITY_IDX[r.id] = i end
for i, q in D.QUALITIES do D.QUALITY[q.id] = q; D.QUALITY_IDX[q.id] = i end

-- cago/come/vel/pelea 1-10; ears = floppy|pointy; size = tamaño relativo (look propio de Roblox)
local function B(id, name, rarity, produce, body, spot, speed, cago, come, vel, ears, size)
	return { id = id, name = name, rarity = rarity, produce = produce, body = c(body), spot = spot and c(spot),
		baseSpeed = speed, cago = cago, come = come, vel = vel, ears = ears, size = size }
end
D.BREEDS = {
	B("callejero", "Callejero", "comun", 1.0, "#a08361", "#5e4a30", 1.0, 4, 5, 6, "pointy", 0.9),
	B("beagle", "Beagle", "comun", 1.1, "#d8b27d", "#3a2410", 1.1, 5, 4, 7, "floppy", 0.95),
	B("labrador", "Labrador", "comun", 1.2, "#e9d29a", nil, 1.0, 6, 7, 6, "floppy", 1.1),
	B("pug", "Pug", "comun", 0.9, "#e2c79b", "#1a1409", 0.7, 4, 7, 3, "floppy", 0.8),
	B("chihuahua", "Chihuahua", "comun", 0.8, "#c69561", "#5a3a1a", 1.4, 3, 2, 9, "pointy", 0.6),
	B("bulldog", "Bulldog", "comun", 1.0, "#d9b08c", "#5b3a1c", 0.7, 5, 8, 3, "floppy", 0.95),
	B("corgi", "Corgi", "comun", 1.1, "#d18a4a", "#fff5e0", 0.9, 5, 6, 6, "pointy", 0.8),
	B("poodle", "Poodle", "comun", 1.0, "#f3eee5", nil, 1.1, 4, 5, 7, "floppy", 0.9),
	B("husky", "Husky", "raro", 1.5, "#e8edf2", "#2c2c34", 1.3, 6, 8, 9, "pointy", 1.1),
	B("pastor", "Pastor Alemán", "raro", 1.7, "#8c5a2c", "#1a1207", 1.2, 7, 7, 8, "pointy", 1.2),
	B("dalmata", "Dálmata", "raro", 1.4, "#f3eee5", "#1a1814", 1.2, 6, 6, 8, "floppy", 1.15),
	B("border", "Border Collie", "raro", 1.6, "#1a1814", "#f3eee5", 1.5, 6, 5, 9, "floppy", 1.0),
	B("golden", "Golden Retriever", "raro", 1.7, "#e7c47b", nil, 1.1, 7, 7, 7, "floppy", 1.15),
	B("gran_danes", "Gran Danés", "raro", 1.8, "#d3c8b5", "#3b2c1c", 1.1, 8, 9, 6, "floppy", 1.5),
	B("shiba", "Shiba Inu", "epico", 2.2, "#d97e2c", "#fff5e0", 1.3, 7, 5, 8, "pointy", 0.95),
	B("akita", "Akita", "epico", 2.4, "#c98a3a", "#fff8ec", 1.1, 8, 6, 7, "pointy", 1.2),
	B("samoyedo", "Samoyedo", "epico", 2.3, "#f8f5ec", nil, 1.2, 7, 7, 8, "pointy", 1.1),
	B("aurodog", "Áurodog", "legend", 4.5, "#fbbf24", "#92400e", 1.4, 9, 5, 8, "pointy", 1.2),
	B("lobo", "Lobo Real", "legend", 4.2, "#5d6470", "#1d212a", 1.7, 8, 8, 10, "pointy", 1.3),
	B("mecanico", "Cyberdog", "legend", 5.0, "#34d6e8", "#1d2940", 1.5, 10, 3, 9, "pointy", 1.2),
	B("fenrir", "Fenrir", "mitico", 8.5, "#9333ea", "#1f0a3c", 1.6, 10, 7, 9, "pointy", 1.5),
	B("cerbero", "Cerbero", "mitico", 9.0, "#dc2626", "#1c0606", 1.5, 10, 8, 8, "pointy", 1.5),
	B("estelar", "Can Estelar", "cosmico", 16.0, "#ec4899", "#fbbf24", 1.5, 10, 4, 9, "pointy", 1.3),
}
D.BREED = {}
for _, b in D.BREEDS do D.BREED[b.id] = b end

-- Solo los rasgos que ya tienen efecto en el port
D.TRAITS = {
	productor = { name = "Productor nato", kind = "pos", icon = "⚡" },
	estomago = { name = "Estómago eficiente", kind = "pos", icon = "🍖" },
	hiperactivo = { name = "Hiperactivo", kind = "pos", icon = "💨" },
	felizpornat = { name = "Feliz por naturaleza", kind = "pos", icon = "😊" },
	olfato = { name = "Olfato de tesoro", kind = "pos", icon = "🧭" },
	digestion = { name = "Digestión premium", kind = "pos", icon = "✨" },
	gloton = { name = "Glotón", kind = "neg", icon = "🍔" },
	perezoso = { name = "Perezoso", kind = "neg", icon = "😴" },
	malcomedor = { name = "Mal comedor", kind = "neg", icon = "🙅" },
	fantasma = { name = "Fantasma", kind = "esp", icon = "👻" },
	iman = { name = "Imán de suerte", kind = "esp", icon = "🍀" },
}
D.TRAIT_POOL = { pos = {}, neg = {}, esp = {} }
for id, t in D.TRAITS do table.insert(D.TRAIT_POOL[t.kind], id) end

D.PACKS = {
	{ id = "food", name = "Sobre de Comida", desc = "Comida, suministros y algún perro común.", icon = "📦", cost = 30,
		rarity = { comun = 80, raro = 16, epico = 3, legend = 1, mitico = 0, cosmico = 0 },
		drops = { food = 65, dog = 10, upgrade = 5, object = 5, other = 5, bowl = 10 } },
	{ id = "dog", name = "Sobre de Perros", desc = "Más probabilidad de perros.", icon = "🎁", cost = 120,
		rarity = { comun = 55, raro = 28, epico = 11, legend = 5, mitico = 1, cosmico = 0 },
		drops = { food = 18, dog = 50, upgrade = 6, object = 6, other = 17, bowl = 3 } },
	{ id = "legend", name = "Sobre Legendario", desc = "Garantiza raro+ en el x10. Más chance de míticos.", icon = "🌟", cost = 500,
		rarity = { comun = 25, raro = 35, epico = 24, legend = 12, mitico = 3, cosmico = 1 },
		drops = { food = 8, dog = 60, upgrade = 5, object = 5, other = 22, bowl = 0 } },
	{ id = "mitico", name = "Sobre Mítico", desc = "Casi solo perros. Épico o mejor la mayoría.", icon = "🔥", cost = 1000000,
		rarity = { comun = 0, raro = 20, epico = 40, legend = 28, mitico = 10, cosmico = 2 },
		drops = { food = 0, dog = 85, upgrade = 5, object = 5, other = 5, bowl = 0 } },
	{ id = "cosmico", name = "Sobre Cósmico", desc = "Lo mejor de lo mejor. Para el final del juego.", icon = "🌌", cost = 150000000,
		rarity = { comun = 0, raro = 0, epico = 30, legend = 40, mitico = 22, cosmico = 8 },
		drops = { food = 0, dog = 95, upgrade = 0, object = 0, other = 5, bowl = 0 } },
}
D.PACK = {}
for _, p in D.PACKS do D.PACK[p.id] = p end

D.FOODS = {
	{ id = "croquetas", name = "Croquetas básicas", icon = "🥣", cost = 5, hunger = 18, happy = 1 },
	{ id = "lata", name = "Lata sabrosa", icon = "🥫", cost = 14, hunger = 30, happy = 5 },
	{ id = "snack", name = "Snack digestivo", icon = "🍪", cost = 22, hunger = 14, happy = 8, fx = "digest" },
	{ id = "hueso", name = "Hueso energético", icon = "🦴", cost = 40, hunger = 25, happy = 6, fx = "speed" },
	{ id = "premium", name = "Comida premium", icon = "🍖", cost = 90, hunger = 50, happy = 12, fx = "productive" },
	{ id = "banquete", name = "Banquete canino", icon = "🍱", cost = 180, hunger = 80, happy = 20, fx = "productive2" },
}
D.FOOD = {}
for _, f in D.FOODS do D.FOOD[f.id] = f end
-- efecto -> multiplicador, duración (s)
D.FOOD_FX = { digest = { "prod", 1.15, 30 }, speed = { "speed", 1.2, 30 }, productive = { "prod", 1.25, 30 }, productive2 = { "prod", 1.35, 60 } }
D.FOOD_FX_TEXT = { digest = "+15% producción 30s", speed = "+20% velocidad 30s", productive = "+25% producción 30s", productive2 = "+35% producción 60s" }

D.UPGRADES = {
	{ id = "production", name = "Productividad canina", desc = "Más producción de popó de todos los perros.", icon = "⚡", max = 25,
		cost = function(l) return math.floor(100 * 1.65 ^ l) end, effect = function(l) return 1 + l * 0.10 end },
	{ id = "magnet", name = "Imán de popó", desc = "Radio mayor para recoger popó al pasar cerca.", icon = "🧲", max = 12,
		cost = function(l) return math.floor(160 * 1.8 ^ l) end, effect = function(l) return l * 1.2 end }, -- studs extra
	{ id = "value", name = "Popó valiosa", desc = "Cada popó vale más.", icon = "💰", max = 20,
		cost = function(l) return math.floor(220 * 1.7 ^ l) end, effect = function(l) return 1 + l * 0.15 end },
	{ id = "happy", name = "Parque feliz", desc = "Los perros pierden menos felicidad.", icon = "😊", max = 10,
		cost = function(l) return math.floor(280 * 1.75 ^ l) end, effect = function(l) return math.max(0.4, 1 - l * 0.06) end },
	{ id = "hunger", name = "Estómago grande", desc = "Los perros tardan más en tener hambre.", icon = "🍖", max = 10,
		cost = function(l) return math.floor(320 * 1.75 ^ l) end, effect = function(l) return math.max(0.4, 1 - l * 0.06) end },
	{ id = "goldenchance", name = "Suerte dorada", desc = "Más probabilidad de popós doradas.", icon = "✨", max = 10,
		cost = function(l) return math.floor(440 * 1.8 ^ l) end, effect = function(l) return 0.05 + l * 0.015 end },
}
D.UPGRADE = {}
for _, u in D.UPGRADES do D.UPGRADE[u.id] = u end

-- Objetos del parque con efecto ya implementado
D.OBJECTS = {
	{ id = "cap_basic", name = "Caseta para perros", desc = "+2 capacidad del parque.", icon = "🏠", cost = 250, max = 8 },
	{ id = "cap_pro", name = "Caseta premium", desc = "+4 capacidad del parque.", icon = "🏛️", cost = 1200, max = 6 },
	{ id = "bowl_extra", name = "Plato extra", desc = "Añade un plato al parque.", icon = "🥣", cost = 180, max = 6 },
	{ id = "bowl_capacity", name = "Plato amplio", desc = "+5 capacidad de todos los platos.", icon = "🍱", cost = 400, max = 5 },
	{ id = "agility", name = "Zona de Agility", desc = "+10% velocidad de los perros.", icon = "🏁", cost = 1300, max = 2 },
	{ id = "gold_statue", name = "Estatua del Perro Dorado", desc = "+10% producción global.", icon = "🗿", cost = 3200, max = 2 },
	{ id = "chef_perruno", name = "Chef Perruno", desc = "−25% costo de comprar comida.", icon = "👨‍🍳", cost = 2200, max = 2 },
}
D.OBJECT = {}
for _, o in D.OBJECTS do D.OBJECT[o.id] = o end

-- type: collect | totalPoop | activeDogs | packsOpened | fever | rarity | breeds | quality
D.MISSIONS = {
	{ title = "Recolecta tu primera popó", desc = "Pasa por encima de una popó.", type = "collect", target = 1, poop = 25 },
	{ title = "Tienes 3 perros activos", desc = "Activa 3 perros desde la pestaña Perros.", type = "activeDogs", target = 3, poop = 60 },
	{ title = "Acumula 200 popós", desc = "Gana 200 popós en total.", type = "totalPoop", target = 200, poop = 80, packs = { food = 1 } },
	{ title = "Abre 3 sobres", desc = "Compra y abre 3 sobres cualesquiera.", type = "packsOpened", target = 3, poop = 120 },
	{ title = "Activa la Fiebre del Parque", desc = "Llena el medidor de fiebre con combos.", type = "fever", target = 1, poop = 300 },
	{ title = "Consigue un perro Épico", desc = "Obtén un perro de rareza Épico o superior.", type = "rarity", min = "epico", target = 1, poop = 500, packs = { dog = 2 } },
	{ title = "10 razas en colección", desc = "Descubre 10 razas distintas.", type = "breeds", target = 10, poop = 800, packs = { legend = 1 } },
	{ title = "Calidad Dorada", desc = "Consigue un perro de calidad Dorada o superior.", type = "quality", min = "dorado", target = 1, poop = 1500, packs = { legend = 2 } },
}

return D
