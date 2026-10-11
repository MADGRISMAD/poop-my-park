-- Nivel del cuidador (XP), misiones y ganancias offline.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage.Shared.Data)
local State = require(script.Parent.State)

local M = {}

function M.xpFor(lvl) return math.floor(Data.HOOKS.XpBase * Data.HOOKS.XpGrowth ^ (lvl - 1)) end

local function grant(S, poop, packs)
	if poop then State.addPoop(S, poop) end
	for k, v in packs or {} do S.data.packs[k] = (S.data.packs[k] or 0) + v end
end

function M.gainXP(S, n)
	local d = S.data
	d.xp += n
	while d.xp >= M.xpFor(d.level) do
		d.xp -= M.xpFor(d.level)
		d.level += 1
		local lvl = d.level
		local poop = math.max(math.round(40 * lvl ^ 1.5), #d.active * 18)
		local packs = {}
		if lvl % 5 == 0 then packs.dog = 1 end
		if lvl % 10 == 0 then packs.legend = 1 end
		if lvl % 3 == 0 then packs.food = 2 end
		grant(S, poop, packs)
		State.notify(S, `¡NIVEL {lvl}!`, "banner", `+{poop} 💩` .. (packs.dog and " · +1 🎁" or "") .. (packs.legend and " · +1 🌟" or "") .. (packs.food and " · +2 📦" or ""))
	end
	S.dirty = true
end

local function missionProgress(S, m)
	local d = S.data
	if m.type == "collect" then return d.stats.collected
	elseif m.type == "totalPoop" then return d.stats.totalPoop
	elseif m.type == "activeDogs" then return #d.active
	elseif m.type == "packsOpened" then return d.stats.packs
	elseif m.type == "fever" then return d.stats.fever > 0 and 1 or 0
	elseif m.type == "breeds" then
		local n = 0
		for _ in d.discovered do n += 1 end
		return n
	end
	-- rarity / quality: algún perro igual o mejor que el mínimo
	local idx, key = Data.RARITY_IDX, "rarity"
	if m.type == "quality" then idx, key = Data.QUALITY_IDX, "quality" end
	for _, dog in d.dogs do
		if idx[dog[key]] >= idx[m.min] then return 1 end
	end
	return 0
end

function M.tick(S)
	local m = Data.MISSIONS[S.data.mission]
	if not m then return end
	local p = missionProgress(S, m)
	S.mProg = math.min(p, m.target)
	if p >= m.target then
		grant(S, m.poop, m.packs)
		S.data.mission += 1
		S.mProg = 0
		State.notify(S, "¡Misión completada!", "toast", m.title)
		if not Data.MISSIONS[S.data.mission] then S.mProg = nil end
	end
	S.dirty = true
end

-- ganancias mientras no estabas (máx 4h, 50% de eficiencia), como en el original
function M.offline(S, lastSaved)
	if not lastSaved then return end
	local elapsed = math.min(4 * 3600, os.time() - lastSaved)
	if elapsed < 60 then return end
	local total = 0
	for _, id in S.data.active do
		local dog = S.data.dogs[id]
		if dog then
			local ri = Data.RARITY_IDX[dog.rarity]
			local base = ({ 1, 1.5, 2.2 })[ri] or 4
			total += elapsed / 10 * base * (dog.age == "baby" and 0.2 or dog.age == "young" and 0.6 or 1)
				* State.upg(S, "production") * State.upg(S, "value")
		end
	end
	total = math.floor(total * 0.5)
	if total > 0 then
		State.addPoop(S, total)
		State.notify(S, "¡Bienvenido de vuelta!", "toast", `Tus perros ganaron {total} 💩 mientras no estabas`)
	end
end

return M
