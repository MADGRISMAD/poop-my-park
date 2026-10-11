-- Progresión de largo plazo: zonas, renacer, recompensa diaria, regalos por tiempo, códigos y boosts.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage.Shared.Data)
local State = require(script.Parent.State)
local Dogs = require(script.Parent.Dogs)

local M = {}

-- códigos solo en el servidor para que no se puedan leer desde el cliente
local CODES = {
	LANZAMIENTO = { poop = 500, packs = { dog = 1 } },
	POPO = { boost = "poop", min = 15 },
	PERRITOS = { packs = { dog = 3 } },
	SUERTE = { boost = "luck", min = 15 },
}

local function today() return os.time() // 86400 end


-- entrega una recompensa y devuelve su texto
function M.grant(S, r)
	local d = S.data
	if r.poop then State.addPoop(S, Data.scalePoop(r.poop, d.level)) end
	for id, n in r.packs or {} do d.packs[id] = (d.packs[id] or 0) + n end
	if r.boost then d.boosts[r.boost] = math.max(d.boosts[r.boost] or 0, os.time()) + r.min * 60 end
	S.dirty = true
	return Data.rewardText(r, d.level)
end

-- desbloquea el siguiente tipo de parque y te muda a él
function M.buyPark(S, k)
	local d = S.data
	local z = Data.ZONES[k]
	if not z or k ~= d.zones + 1 then return { ok = false } end
	if d.poop < z.cost then return { ok = false, msg = "No te alcanza 💩" } end
	d.poop -= z.cost
	d.zones, d.park = k, k
	S.onZones()
	State.notify(S, `¡{string.upper(z.name)} DESBLOQUEADO! {z.icon}`, "banner", `Tu popó ahora vale x{z.mult}`)
	return { ok = true }
end

function M.selectPark(S, k)
	if typeof(k) ~= "number" or k < 1 or k > S.data.zones then return { ok = false } end
	S.data.park = k
	S.onZones()
	return { ok = true }
end

function M.rebirth(S)
	local d = S.data
	local cost = Data.rebirthCost(d.rebirths)
	if d.poop < cost then return false end
	local tokens = Data.rebirthTokens(d.rebirths)
	d.rebirths += 1
	d.tokens += tokens
	d.poop, d.upgrades, d.objects, d.zones, d.park = 0, {}, {}, 1, 1
	for i = #d.active, State.capacity(S) + 1, -1 do Dogs.deactivate(S, d.active[i]) end
	Dogs.syncBowls(S)
	S.onZones()
	State.notify(S, "¡RENACISTE!", "banner", `Popó x{Data.rebirthMult(d.rebirths)} para siempre · +{tokens} 🔄`)
	return true
end

function M.buyPerk(S, id)
	local p = Data.PERK[id]
	if not p then return { ok = false } end
	local lvl = S.data.perks[id] or 0
	if lvl >= p.max then return { ok = false } end
	if S.data.tokens < p.cost(lvl) then return { ok = false, msg = "Te faltan fichas 🔄 (renace para conseguir más)" } end
	S.data.tokens -= p.cost(lvl)
	S.data.perks[id] = lvl + 1
	S.dirty = true
	return { ok = true }
end

function M.claimDaily(S)
	local d = S.data
	if d.daily.last == today() then return false end
	d.daily.streak = d.daily.last == today() - 1 and d.daily.streak + 1 or 1
	d.daily.last = today()
	local r = Data.DAILY[(d.daily.streak - 1) % #Data.DAILY + 1]
	State.notify(S, `¡DÍA {d.daily.streak}!`, "banner", M.grant(S, r))
	return true
end

function M.claimGift(S, i)
	local g = Data.GIFTS[i]
	if not g or S.gifts[i] or os.clock() - S.joined < g.t then return false end
	S.gifts[i] = true
	State.notify(S, "¡Regalo!", "toast", M.grant(S, g))
	return true
end

function M.redeem(S, code)
	if typeof(code) ~= "string" then return { ok = false } end
	code = string.upper(code:gsub("%s", ""))
	local r = CODES[code]
	if not r then return { ok = false, msg = "Código inválido" } end
	if S.data.codes[code] then return { ok = false, msg = "Ya usaste ese código" } end
	S.data.codes[code] = true
	return { ok = true, msg = "Código canjeado: " .. M.grant(S, r) }
end

-- retos diarios: 3 por día, iguales para todo el servidor -----------------------------
local QUEST_STATS = { "collected", "packs", "mutations", "fusions", "fever" }
local function todaysQuests()
	local r = Random.new(today())
	local idx = {}
	for i in Data.QUESTS do table.insert(idx, i) end
	for i = #idx, 2, -1 do
		local j = r:NextInteger(1, i)
		idx[i], idx[j] = idx[j], idx[i]
	end
	return { idx[1], idx[2], idx[3] }
end
local function ensureQuests(S)
	local q, st = S.data.quests, S.data.stats
	if q.day ~= today() then
		q.day, q.base, q.claimed, q.bonus = today(), {}, {}, false
		for _, k in QUEST_STATS do q.base[k] = st[k] end
	end
	return q
end
local function questProgress(S, quest)
	local q = ensureQuests(S)
	return math.min(quest.target, S.data.stats[quest.type] - (q.base[quest.type] or 0))
end

function M.claimQuest(S, i)
	local q = ensureQuests(S)
	local qi = todaysQuests()[i]
	local quest = qi and Data.QUESTS[qi]
	if not quest or q.claimed[tostring(i)] or questProgress(S, quest) < quest.target then return { ok = false } end
	q.claimed[tostring(i)] = true
	State.notify(S, "¡Reto completado!", "toast", M.grant(S, quest.reward))
	if not q.bonus and q.claimed["1"] and q.claimed["2"] and q.claimed["3"] then
		q.bonus = true
		State.notify(S, "¡TODOS LOS RETOS!", "banner", M.grant(S, Data.QUEST_BONUS))
	end
	return { ok = true }
end

-- índice de razas: premios por descubrir
function M.claimIndex(S, i)
	local r = Data.INDEX_REWARDS[i]
	local n = 0
	for _ in S.data.discovered do n += 1 end
	if not r or n < r.n or S.data.indexClaimed[tostring(i)] then return { ok = false } end
	S.data.indexClaimed[tostring(i)] = true
	State.notify(S, `¡ÍNDICE: {r.n} RAZAS!`, "banner", M.grant(S, r.reward))
	return { ok = true }
end

function M.snapshot(S)
	local d = S.data
	local claimable = d.daily.last ~= today()
	local streak = (d.daily.last >= today() - 1) and d.daily.streak or 0
	local nextDay = claimable and streak + 1 or streak
	local claimed = {}
	for i in S.gifts do table.insert(claimed, i) end
	local q = ensureQuests(S)
	local quests = {}
	for i, qi in todaysQuests() do
		local quest = Data.QUESTS[qi]
		table.insert(quests, { title = quest.title, target = quest.target, progress = questProgress(S, quest),
			claimed = q.claimed[tostring(i)] == true, reward = Data.rewardText(quest.reward, d.level), icon = Data.rewardIcon(quest.reward) })
	end
	local discovered, indexClaimed = {}, {}
	for id in d.discovered do table.insert(discovered, id) end
	for k in d.indexClaimed do table.insert(indexClaimed, tonumber(k)) end
	return {
		zones = d.zones, park = d.park, rebirths = d.rebirths, rebirthCost = Data.rebirthCost(d.rebirths),
		tokens = d.tokens, perks = d.perks, nextTokens = Data.rebirthTokens(d.rebirths),
		quests = quests, questBonus = ensureQuests(S).bonus, discovered = discovered, indexClaimed = indexClaimed,
		friends = math.min(S.friends or 0, 5),
		daily = { can = claimable, streak = streak, next = (nextDay - 1) % #Data.DAILY + 1 },
		session = os.clock() - S.joined, gifts = claimed,
		boosts = { poop = State.boostLeft(S, "poop"), luck = State.boostLeft(S, "luck") },
	}
end

return M
