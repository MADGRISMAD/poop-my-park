-- Compra y apertura de sobres (drops del original; los que dependen de sistemas aún no portados dan comida).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Data = require(ReplicatedStorage.Shared.Data)
local State = require(script.Parent.State)
local Dogs = require(script.Parent.Dogs)
local Progress = require(script.Parent.Progress)

local rng = Random.new()
local M = {}

local function weighted(entries)
	local total = 0
	for _, e in entries do total += e[2] end
	local r = rng:NextNumber() * total
	for _, e in entries do
		r -= e[2]
		if r <= 0 then return e[1] end
	end
	return entries[#entries][1]
end

function M.buy(S, packId, qty)
	local pack = Data.PACK[packId]
	if not pack or (qty ~= 1 and qty ~= 10) then return false end
	local cost = pack.cost * qty
	if S.data.poop < cost then return false end
	S.data.poop -= cost
	S.data.packs[packId] = (S.data.packs[packId] or 0) + qty
	S.dirty = true
	return true
end

local FOOD_ROLL = { { "croquetas", 60 }, { "lata", 25 }, { "snack", 10 }, { "hueso", 4 }, { "premium", 1 } }

local function giveFood(S)
	local id, qty = weighted(FOOD_ROLL), rng:NextInteger(1, 3)
	S.data.food[id] = (S.data.food[id] or 0) + qty
	local f = Data.FOOD[id]
	return { kind = "item", icon = f.icon, name = f.name, qty = qty }
end

local function giveObject(S, id)
	local o = Data.OBJECT[id]
	local have = S.data.objects[id] or 0
	if have >= o.max then return giveFood(S) end
	S.data.objects[id] = have + 1
	return { kind = "item", icon = o.icon, name = o.name, qty = 1 }
end

local function openOne(S, pack)
	local entries = {}
	for k, w in pack.drops do table.insert(entries, { k, w }) end
	local cat = weighted(entries)
	if cat == "dog" then
		local dog, isNew = Dogs.create(S, { weights = pack.rarity })
		local r = Data.RARITY[dog.rarity]
		if Data.RARITY_IDX[dog.rarity] >= 4 then
			State.AnnounceEv:FireAllClients(`¡{S.player.DisplayName} sacó un {r.name} {Data.BREED[dog.breed].name}!`, r.color)
		end
		return { kind = "dog", dog = State.dogInfo(S, dog), new = isNew }
	elseif cat == "upgrade" then
		local u = Data.UPGRADES[rng:NextInteger(1, #Data.UPGRADES)]
		local lvl = S.data.upgrades[u.id] or 0
		if lvl >= u.max then return giveFood(S) end
		S.data.upgrades[u.id] = lvl + 1
		return { kind = "item", icon = u.icon, name = u.name .. " +1", qty = 1 }
	elseif cat == "object" then
		return giveObject(S, Data.OBJECTS[rng:NextInteger(1, #Data.OBJECTS)].id)
	elseif cat == "bowl" then
		return giveObject(S, "bowl_capacity")
	end
	return giveFood(S) -- "food" y "other"
end

local RARE_PLUS = { raro = true, epico = true, legend = true, mitico = true, cosmico = true }

function M.open(S, packId, ten)
	local pack = Data.PACK[packId]
	local n = ten and 10 or 1
	if not pack or (S.data.packs[packId] or 0) < n then return nil end
	S.data.packs[packId] -= n
	S.data.stats.packs += n
	Progress.gainXP(S, Data.HOOKS.XpPack * n)
	local results = {}
	for _ = 1, n do table.insert(results, openOne(S, pack)) end
	if ten and packId == "legend" then
		local ok = false
		for _, r in results do
			if r.kind == "dog" and RARE_PLUS[r.dog.rarity] then ok = true end
		end
		if not ok then
			local dog, isNew = Dogs.create(S, { weights = { comun = 0, raro = 100, epico = 30, legend = 10, mitico = 2, cosmico = 0 } })
			table.insert(results, { kind = "dog", dog = State.dogInfo(S, dog), new = isNew })
		end
	end
	S.dirty = true
	return results
end

return M
