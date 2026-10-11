-- Ventanas del menú: sobres, perros, mejoras, tienda y comida, con cartas en cuadrícula.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Data = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"))
local UI = require(script.Parent.UI)
local Pets = require(script.Parent.Pets)
local Hatch = require(script.Parent.Hatch)

local C = UI.C
local M = {}
M.TABS = {
	packs = { title = "SOBRES", color = C.pink, icon = "🎁" },
	dogs = { title = "MIS PERROS", color = C.blue, icon = "🐶" },
	upgrades = { title = "MEJORAS", color = C.purple, icon = "⚡" },
	shop = { title = "TIENDA", color = C.orange, icon = "🏪" },
	food = { title = "COMIDA", color = C.green, icon = "🍖" },
	rebirth = { title = "RENACER", color = C.red, icon = "🔄" },
	gear = { title = "EQUIPO", color = C.blue, icon = "🧰" },
	parks = { title = "PARQUES", color = C.green, icon = "🗺️" },
	quests = { title = "RETOS", color = C.orange, icon = "🎯" },
	index = { title = "ÍNDICE", color = C.brown, icon = "📖" },
	gifts = { title = "REGALOS", color = C.pink, icon = "🎁" },
	daily = { title = "DIARIO", color = C.blue, icon = "📅" },
	codes = { title = "CÓDIGOS", color = C.purple, icon = "🎟️" },
}
M.ORDER = { "dogs", "upgrades", "shop", "food", "parks" } -- sobres y equipo se abren en sus quioscos
M.RIGHT = { "gifts", "daily", "quests", "index", "codes", "rebirth" }
local PACK_COLOR = { food = C.green, dog = C.blue, legend = C.gold, mitico = C.red, cosmico = C.purple }
local AGES = { baby = "Bebé", young = "Joven", adult = "Adulto", veteran = "Veterano" }

-- grupos que ya se pueden fusionar: misma raza y nivel, 3+ perros. Elige los 3 más grandes.
function M.fusionSuggestions(dogs)
	local groups = {}
	for _, d in dogs do
		if d.fusion < Data.FUSION.Max then
			local key = d.breed .. "#" .. d.fusion
			groups[key] = groups[key] or {}
			table.insert(groups[key], d)
		end
	end
	local out = {}
	for _, g in groups do
		if #g >= Data.FUSION.Need then
			table.sort(g, function(a, b) return a.size > b.size end) -- siempre los más grandes
			table.insert(out, { table.unpack(g, 1, Data.FUSION.Need) })
		end
	end
	table.sort(out, function(a, b)
		return Data.RARITY_IDX[a[1].rarity] * 10 + a[1].fusion > Data.RARITY_IDX[b[1].rarity] * 10 + b[1].fusion
	end)
	return out
end

function M.new(gui, act)
	local self = {}
	local snap, snapAt, tab, sig
	local fuseMode, fuseSel = false, {}
	local rebuild
	local afford, hungerBars, live = {}, {}, {}

	local window = UI.box(gui, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.53), Size = UDim2.fromOffset(820, 520), Visible = false }, C.panel, 24)
	local wscale = UI.autoscale(window)
	local header = UI.box(window, { Position = UDim2.fromOffset(-4, -4), Size = UDim2.new(1, 8, 0, 70) }, C.pink, 24)
	local title = UI.text(header, { Position = UDim2.fromOffset(24, 8), Size = UDim2.new(1, -120, 1, -16), TextXAlignment = Enum.TextXAlignment.Left }, 3)
	local close = UI.button(window, "X", C.red, function() self.close() end, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -8, 0, 4), Size = UDim2.fromOffset(56, 56) })
	close.ZIndex = 5
	local toolbar = UI.new("Frame", { Position = UDim2.fromOffset(18, 80), Size = UDim2.new(1, -36, 0, 48), BackgroundTransparency = 1 }, window)
	local scroll = UI.new("ScrollingFrame", { BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 10, ScrollBarImageColor3 = C.ink, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new() }, window)

	local function btn(parent, label, color, cb, cost, props)
		local b = UI.button(parent, label, color, cb, props)
		if cost then table.insert(afford, { b, cost, color }) end
		return b
	end
	local function grid(cell)
		UI.new("UIGridLayout", { CellSize = cell, CellPadding = UDim2.fromOffset(14, 14), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
		UI.new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 12) }, scroll)
	end
	local function useToolbar(on)
		toolbar.Visible = on
		local top = on and 134 or 84
		scroll.Position, scroll.Size = UDim2.fromOffset(14, top), UDim2.new(1, -28, 1, -top - 14)
	end

	-- tarjeta horizontal para mejoras / tienda / comida
	local function wideCard(i, icon, name, sub, desc, bar, parent)
		local card = UI.box(parent or scroll, { LayoutOrder = i }, C.panel2, 16)
		UI.text(card, { Text = icon, Position = UDim2.fromOffset(10, 14), Size = UDim2.fromOffset(80, 80) }, 0)
		UI.text(card, { Text = name, Position = UDim2.fromOffset(96, 8), Size = UDim2.new(1, -250, 0, 28), TextXAlignment = Enum.TextXAlignment.Left }, 2.5)
		UI.text(card, { Text = sub, Position = UDim2.fromOffset(96, 36), Size = UDim2.new(1, -250, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.gold }, 2)
		UI.text(card, { Text = desc, FontFace = UI.BODY, Position = UDim2.fromOffset(96, 58), Size = UDim2.new(1, -250, 0, 36), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextScaled = false, TextSize = 15, TextWrapped = true, TextColor3 = C.ink }, 0)
		if bar then
			local back = UI.new("Frame", { Position = UDim2.fromOffset(96, 98), Size = UDim2.new(1, -250, 0, 12), BackgroundColor3 = UI.dark(C.panel2, 0.25), BorderSizePixel = 0 }, card)
			UI.corner(back, 6)
			local fill = UI.new("Frame", { Size = UDim2.fromScale(math.clamp(bar, 0, 1), 1), BorderSizePixel = 0 }, back)
			UI.corner(fill, 6)
			UI.grad(fill, UI.light(C.green, 0.3), C.green)
		end
		local holder = UI.new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(140, 104), BackgroundTransparency = 1 }, card)
		UI.new("UIListLayout", { Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center }, holder)
		return holder
	end

	local builders = {}
	function builders.packs()
		useToolbar(false)
		grid(UDim2.fromOffset(244, 372))
		for i, p in Data.PACKS do
			local own = snap.packs[p.id] or 0
			local card = UI.box(scroll, { LayoutOrder = i }, PACK_COLOR[p.id], 20)
			UI.text(card, { Text = p.icon, Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 100) }, 0)
			UI.text(card, { Text = p.name, Position = UDim2.fromOffset(10, 116), Size = UDim2.new(1, -20, 0, 34) }, 3)
			UI.text(card, { Text = p.desc, FontFace = UI.BODY, Position = UDim2.fromOffset(14, 152), Size = UDim2.new(1, -28, 0, 40), TextScaled = false, TextSize = 15, TextWrapped = true }, 1.5)
			UI.text(card, { Text = `TIENES: {own}`, Position = UDim2.fromOffset(10, 196), Size = UDim2.new(1, -20, 0, 26), TextColor3 = own > 0 and C.white or UI.light(C.ink, 0.5) }, 2.5)
			local holder = UI.new("Frame", { Position = UDim2.fromOffset(12, 232), Size = UDim2.new(1, -24, 0, 126), BackgroundTransparency = 1 }, card)
			UI.new("UIGridLayout", { CellSize = UDim2.new(0.5, -5, 0, 58), CellPadding = UDim2.fromOffset(10, 10) }, holder)
			local function open(ten)
				task.spawn(function()
					local r = act("openPack", p.id, ten)
					if r and r.results then Hatch.play(gui, r.results, p.id) end
				end)
			end
			btn(holder, `{p.cost} 💩`, C.gold, function() act("buyPack", p.id, 1) end, p.cost)
			btn(holder, `x10 {UI.fmt(p.cost * 10)}`, C.gold, function() act("buyPack", p.id, 10) end, p.cost * 10)
			btn(holder, "ABRIR", own > 0 and C.green or C.grey, function() open(false) end)
			btn(holder, "ABRIR x10", own >= 10 and C.green or C.grey, function() open(true) end)
		end
	end

	function builders.dogs()
		useToolbar(true)
		if fuseMode then
			local n = 0
			for _ in fuseSel do n += 1 end
			UI.text(toolbar, { Text = `🧬 Elige {Data.FUSION.Need}+ de la misma raza y nivel ({n})`, Size = UDim2.new(1, -400, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.purple }, 2.5)
			btn(toolbar, "CANCELAR", C.grey, function()
				fuseMode, fuseSel, sig = false, {}, nil
				rebuild(true)
			end, nil, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -230, 0, 0), Size = UDim2.fromOffset(160, 48) })
			btn(toolbar, `FUSIONAR ({n})`, n >= Data.FUSION.Need and C.purple or C.grey, function()
				local ids, inputs = {}, {}
				for _, d in snap.dogs do
					if fuseSel[d.id] then
						table.insert(ids, d.id)
						table.insert(inputs, d)
					end
				end
				if #ids < Data.FUSION.Need then return end
				task.spawn(function()
					local r = act("fuse", ids)
					if r and r.ok then
						fuseMode, fuseSel, sig = false, {}, nil
						Hatch.fusion(gui, inputs, r.dog)
					end
				end)
			end, nil, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(220, 48) })
		else
			UI.text(toolbar, { Text = `EQUIPADOS {snap.activeCount}/{snap.capacity}  ·  {#snap.dogs} PERROS`, Size = UDim2.new(1, -420, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.blue }, 2.5)
			btn(toolbar, "🧬 FUSIONAR", C.purple, function()
				fuseMode, fuseSel, sig = true, {}, nil
				rebuild(true)
			end, nil, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -230, 0, 0), Size = UDim2.fromOffset(180, 48) })
			btn(toolbar, "⭐ EQUIPAR MEJORES", C.gold, function() act("equipBest") end, nil, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(220, 48) })
		end
		grid(UDim2.fromOffset(136, 186))
		-- primero, las fusiones sugeridas: un clic y listo
		if not fuseMode then
			for i, group in M.fusionSuggestions(snap.dogs) do
				local d = group[1]
				local ra = Data.RARITY[d.rarity]
				local size, inputs, ids = 0, {}, {}
				for _, g in group do
					size += g.size
					table.insert(ids, g.id)
					table.insert(inputs, g)
				end
				local card = UI.box(scroll, { LayoutOrder = -100 + i }, C.purple, 16)
				card.UIStroke.Color, card.UIStroke.Thickness = C.gold, 5
				UI.text(card, { Text = "🧬 FUSIÓN LISTA", Position = UDim2.fromOffset(4, 6), Size = UDim2.new(1, -8, 0, 20), TextColor3 = C.gold }, 2.5)
				Pets.viewport(card, { breed = d.breed, rarity = d.rarity, quality = d.quality, age = "adult", mutations = {}, fusion = d.fusion + 1, size = size / #group },
					{ Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 84) })
				UI.text(card, { Text = `{#group}x {Data.BREED[d.breed].name}`, Position = UDim2.fromOffset(4, 108), Size = UDim2.new(1, -8, 0, 20), TextColor3 = ra.color }, 2.5)
				UI.text(card, { Text = `➜ {Data.FUSION.Stars[d.fusion + 1]}  x{Data.fusionMult(d.fusion + 1)}`, Position = UDim2.fromOffset(4, 128), Size = UDim2.new(1, -8, 0, 18) }, 2)
				btn(card, "FUSIONAR", C.green, function()
					task.spawn(function()
						local r = act("fuse", ids)
						if r and r.ok then Hatch.fusion(gui, inputs, r.dog) end
					end)
				end, nil, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -14, 0, 32) })
			end
		end
		local list = table.clone(snap.dogs)
		table.sort(list, function(a, b)
			if a.active ~= b.active then return a.active end
			local ra, rb = Data.RARITY_IDX[a.rarity], Data.RARITY_IDX[b.rarity]
			if ra ~= rb then return ra > rb end
			return Data.QUALITY_IDX[a.quality] > Data.QUALITY_IDX[b.quality]
		end)
		for i, d in list do
			local ra, qu, br = Data.RARITY[d.rarity], Data.QUALITY[d.quality], Data.BREED[d.breed]
			local card = UI.box(scroll, { LayoutOrder = i }, UI.light(ra.color, 0.5), 16)
			card.UIStroke.Color = d.active and C.green or UI.dark(ra.color, 0.35)
			card.UIStroke.Thickness = d.active and 5 or 4
			Pets.viewport(card, d, { Size = UDim2.new(1, 0, 0, 104) })
			UI.text(card, { Text = br.name, Position = UDim2.fromOffset(4, 102), Size = UDim2.new(1, -8, 0, 22), TextColor3 = ra.color }, 2.5)
			if #d.mutations > 0 then
				UI.text(card, { Text = Data.mutationIcons(d.mutations), Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -40, 0, 24), TextXAlignment = Enum.TextXAlignment.Left }, 0)
			end
			UI.text(card, { Text = `{qu.name} · Nv.{d.level}`, Position = UDim2.fromOffset(4, 124), Size = UDim2.new(1, -8, 0, 16), TextColor3 = qu.color }, 2)
			UI.text(card, { Text = `📏{Data.sizeLabel(d.size)} {d.fusion > 0 and Data.FUSION.Stars[d.fusion] or ""}`, Position = UDim2.fromOffset(4, 140), Size = UDim2.new(1, -8, 0, 15), TextColor3 = d.fusion > 0 and C.gold or C.white }, 2)
			if fuseMode and fuseSel[d.id] then
				card.UIStroke.Color, card.UIStroke.Thickness = C.purple, 6
				local check = UI.box(card, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.35), Size = UDim2.fromOffset(54, 54), ZIndex = 3 }, C.purple, 27)
				UI.text(check, { Text = "🧬", Size = UDim2.fromScale(1, 1), ZIndex = 4 }, 0)
			end
			local back = UI.new("Frame", { Position = UDim2.fromOffset(12, 162), Size = UDim2.new(1, -24, 0, 10), BackgroundColor3 = UI.dark(ra.color, 0.5), BorderSizePixel = 0 }, card)
			UI.corner(back, 5)
			local fill = UI.new("Frame", { Size = UDim2.fromScale(d.hunger / 100, 1), BackgroundColor3 = C.orange, BorderSizePixel = 0 }, back)
			UI.corner(fill, 5)
			hungerBars[d.id] = fill
			if d.active then
				local badge = UI.box(card, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(34, 34) }, C.green, 17)
				UI.text(badge, { Text = "✓", Size = UDim2.fromScale(1, 1) }, 2)
			end
			local hit = UI.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, card)
			hit.Activated:Connect(function()
				UI.sound("click", 1.2, 0.35)
				if fuseMode then
					fuseSel[d.id] = not fuseSel[d.id] or nil
					sig = nil
					rebuild(false)
				else
					self.showDog(d.id)
				end
			end)
		end
	end

	function builders.upgrades()
		useToolbar(false)
		grid(UDim2.fromOffset(376, 120))
		for i, u in Data.UPGRADES do
			local lvl = snap.upgrades[u.id] or 0
			local maxed = lvl >= u.max
			local h = wideCard(i, u.icon, u.name, `NIVEL {lvl}/{u.max}`, u.desc, lvl / u.max)
			btn(h, maxed and "MÁX" or `{UI.fmt(u.cost(lvl))} 💩`, maxed and C.grey or C.gold, function()
				if not maxed then act("buyUpgrade", u.id) end
			end, not maxed and u.cost(lvl) or nil, { Size = UDim2.fromOffset(140, 56) })
		end
	end

	function builders.shop()
		useToolbar(false)
		grid(UDim2.fromOffset(376, 120))
		for i, o in Data.OBJECTS do
			local have = snap.objects[o.id] or 0
			local maxed = have >= o.max
			local h = wideCard(i, o.icon, o.name, `{have}/{o.max}`, o.desc, have / o.max)
			btn(h, maxed and "MÁX" or `{UI.fmt(o.cost)} 💩`, maxed and C.grey or C.gold, function()
				if not maxed then act("buyObject", o.id) end
			end, not maxed and o.cost or nil, { Size = UDim2.fromOffset(140, 56) })
		end
	end

	function builders.food()
		useToolbar(true)
		UI.text(toolbar, { Text = "Acércate a un plato de tu parque para rellenarlo con la comida ✓", FontFace = UI.BODY, Size = UDim2.fromScale(1, 1), TextColor3 = C.ink }, 0)
		grid(UDim2.fromOffset(376, 120))
		for i, f in Data.FOODS do
			local cost = math.ceil(f.cost * snap.foodCostMult)
			local sel = snap.selectedFood == f.id
			local h = wideCard(i, f.icon, f.name, `TIENES {snap.food[f.id] or 0}`, `🍖 +{f.hunger}  😊 +{f.happy}  {f.fx and Data.FOOD_FX_TEXT[f.fx] or ""}`)
			btn(h, `{cost} 💩`, C.gold, function() act("buyFood", f.id) end, cost, { Size = UDim2.fromOffset(140, 46) })
			btn(h, sel and "✓ EN USO" or "USAR", sel and C.green or C.blue, function() act("selectFood", f.id) end, nil, { Size = UDim2.fromOffset(140, 46) })
		end
	end

	-- tarjeta de recompensa (diario y regalos)
	local function rewardCard(i, top, r, state)
		local colors = { claimed = C.grey, ready = C.green, locked = C.panel2, today = C.gold }
		local card = UI.box(scroll, { LayoutOrder = i }, colors[state], 16)
		UI.text(card, { Text = top, Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, 24) }, 2.5)
		UI.text(card, { Text = Data.rewardIcon(r), Position = UDim2.fromOffset(20, 32), Size = UDim2.new(1, -40, 0, 56) }, 0)
		UI.text(card, { Text = Data.rewardText(r, snap.level), Position = UDim2.fromOffset(6, 92), Size = UDim2.new(1, -12, 0, 34), TextWrapped = true }, 2)
		local foot = UI.text(card, { Text = state == "claimed" and "✓" or "", Position = UDim2.fromOffset(6, 128), Size = UDim2.new(1, -12, 0, 26) }, 2.5)
		return card, foot
	end

	function builders.rebirth()
		useToolbar(true)
		UI.text(toolbar, { Text = `🔄 FICHAS: {snap.tokens}   ·   PRÓXIMO RENACER DA +{snap.nextTokens}`, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.red }, 2.5)
		UI.new("UIListLayout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, scroll)
		UI.new("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 12) }, scroll)
		local r, cost = snap.rebirths, snap.rebirthCost
		local card = UI.box(scroll, { Size = UDim2.new(1, -16, 0, 330), LayoutOrder = 1 }, UI.light(C.red, 0.55), 20)
		UI.text(card, { Text = `RENACIMIENTOS: {r}`, Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -40, 0, 44) }, 3)
		UI.text(card, { Text = `💩 x{Data.rebirthMult(r)}  ➜  x{Data.rebirthMult(r + 1)} PARA SIEMPRE`, Position = UDim2.fromOffset(20, 62), Size = UDim2.new(1, -40, 0, 40), TextColor3 = C.gold }, 3)
		local back = UI.box(card, { Position = UDim2.fromOffset(40, 116), Size = UDim2.new(1, -80, 0, 34) }, UI.dark(C.red, 0.5), 17)
		local fill = UI.new("Frame", { BorderSizePixel = 0 }, back)
		UI.corner(fill, 17)
		UI.grad(fill, UI.light(C.gold, 0.4), C.gold)
		local txt = UI.text(back, { Size = UDim2.new(1, 0, 1, -8), Position = UDim2.fromOffset(0, 4), ZIndex = 2 }, 2.5)
		table.insert(live, function(s)
			fill.Size = UDim2.fromScale(math.clamp(s.poop / cost, 0, 1), 1)
			txt.Text = `{UI.fmt(s.poop)} / {UI.fmt(cost)} 💩`
		end)
		UI.text(card, { Text = "Pierdes: 💩 popó · ⚡ mejoras · 🏪 objetos · 🗺️ zonas", FontFace = UI.BODY, Position = UDim2.fromOffset(20, 162), Size = UDim2.new(1, -40, 0, 30) }, 2)
		UI.text(card, { Text = "Conservas: 🐶 perros · 🎁 sobres · 🍖 comida · ⭐ nivel", FontFace = UI.BODY, Position = UDim2.fromOffset(20, 194), Size = UDim2.new(1, -40, 0, 30) }, 2)
		local confirm = false
		local b
		b = btn(card, "RENACER", C.gold, function()
			if snap.poop < cost then return end
			if not confirm then
				confirm = true
				b:FindFirstChildWhichIsA("TextLabel").Text = "¿SEGURO? TOCA OTRA VEZ"
				return
			end
			act("rebirth")
		end, cost, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 240), Size = UDim2.fromOffset(340, 64) })

		UI.text(scroll, { Text = "🔄 TIENDA DE FICHAS (MEJORAS PERMANENTES)", Size = UDim2.new(1, -16, 0, 36), LayoutOrder = 2, TextColor3 = C.red }, 2.5)
		local perks = UI.new("Frame", { Size = UDim2.new(1, -16, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 3 }, scroll)
		UI.new("UIGridLayout", { CellSize = UDim2.fromOffset(376, 120), CellPadding = UDim2.fromOffset(14, 14), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, perks)
		for i, p in Data.PERKS do
			local lvl = snap.perks[p.id] or 0
			local maxed = lvl >= p.max
			local price = p.cost(lvl)
			local h = wideCard(i, p.icon, p.name, `NIVEL {lvl}/{p.max}`, p.desc, lvl / p.max, perks)
			btn(h, maxed and "MÁX" or `{price} 🔄`, maxed and C.grey or (snap.tokens >= price and C.red or C.grey), function()
				if not maxed then act("buyPerk", p.id) end
			end, nil, { Size = UDim2.fromOffset(140, 56) })
		end
	end

	function builders.parks()
		useToolbar(true)
		UI.text(toolbar, { Text = "Mismo parque, otro lugar. Cada uno multiplica tu popó y favorece una mutación.", FontFace = UI.BODY, Size = UDim2.fromScale(1, 1), TextColor3 = C.ink }, 0)
		grid(UDim2.fromOffset(176, 250))
		for i, z in Data.ZONES do
			local unlocked = i <= snap.zones
			local current = i == snap.park
			local nextOne = i == snap.zones + 1
			local card = UI.box(scroll, { LayoutOrder = i }, unlocked and z.color or UI.dark(z.color, 0.55), 18)
			if current then
				card.UIStroke.Color = C.green
				card.UIStroke.Thickness = 6
			end
			UI.text(card, { Text = unlocked and z.icon or "🔒", Position = UDim2.fromOffset(20, 8), Size = UDim2.new(1, -40, 0, 70) }, 0)
			UI.text(card, { Text = string.upper(z.name), Position = UDim2.fromOffset(6, 80), Size = UDim2.new(1, -12, 0, 30) }, 3)
			UI.text(card, { Text = `💩 x{UI.fmt(z.mult)}`, Position = UDim2.fromOffset(6, 112), Size = UDim2.new(1, -12, 0, 28), TextColor3 = C.gold }, 2.5)
			local bias = ""
			for m, v in z.bias do bias ..= `{Data.MUTATIONS[m].icon} x{v} ` end
			UI.text(card, { Text = bias ~= "" and bias or "—", Position = UDim2.fromOffset(6, 142), Size = UDim2.new(1, -12, 0, 24) }, 2)
			local label, color, cb, cost = "🔒", C.grey, function() end, nil
			if current then
				label, color = "EN USO", C.green
			elseif unlocked then
				label, color, cb = "USAR", C.blue, function() act("selectPark", i) end
			elseif nextOne then
				label, color, cb, cost = `{UI.fmt(z.cost)} 💩`, C.gold, function() act("buyPark", i) end, z.cost
			else
				label = `🔒 {UI.fmt(z.cost)}`
			end
			btn(card, label, color, cb, cost, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.new(1, -24, 0, 54) })
		end
	end

	function builders.daily()
		useToolbar(true)
		local d = snap.daily
		UI.text(toolbar, { Text = `🔥 RACHA: {d.streak} DÍAS`, Size = UDim2.new(1, -230, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.orange }, 2.5)
		btn(toolbar, d.can and "RECLAMAR" or "VUELVE MAÑANA", d.can and C.green or C.grey, function()
			if d.can then act("claimDaily") end
		end, nil, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(220, 48) })
		grid(UDim2.fromOffset(100, 160))
		for i, r in Data.DAILY do
			local state = i < d.next and "claimed" or i == d.next and (d.can and "today" or "claimed") or "locked"
			if not d.can and i == d.next then state = "claimed" end
			rewardCard(i, `DÍA {i}`, r, state)
		end
	end

	function builders.gifts()
		useToolbar(true)
		UI.text(toolbar, { Text = "¡Quédate jugando para abrir más regalos!", Size = UDim2.fromScale(1, 1), TextColor3 = C.pink }, 2.5)
		grid(UDim2.fromOffset(140, 160))
		local claimed = {}
		for _, i in snap.gifts do claimed[i] = true end
		for i, g in Data.GIFTS do
			local ready = snap.session >= g.t
			local state = claimed[i] and "claimed" or ready and "ready" or "locked"
			local card, foot = rewardCard(i, `REGALO {i}`, g, state)
			if state == "ready" then
				foot.Text = "¡RECLAMAR!"
				local hit = UI.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, card)
				hit.Activated:Connect(function() act("claimGift", i) end)
			elseif state == "locked" then
				table.insert(live, function(s)
					local left = math.max(0, g.t - (s.session + os.clock() - snapAt))
					foot.Text = string.format("%d:%02d", left // 60, left % 60)
				end)
			end
		end
	end

	function builders.gear()
		useToolbar(true)
		local timer = UI.text(toolbar, { Size = UDim2.new(0.6, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.blue }, 2.5)
		UI.text(toolbar, { Text = `COLOCADOS {snap.gearPlaced}/{Data.MAX_GEAR}`, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.4, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right }, 2.5)
		table.insert(live, function()
			local left = math.max(0, (workspace:GetAttribute("RestockAt") or 0) - workspace:GetServerTimeNow())
			timer.Text = string.format("🛒 REABASTECE EN %d:%02d", left // 60, left % 60)
		end)
		grid(UDim2.fromOffset(376, 120))
		for i, it in Data.SHOP do
			local def = Data.item(it.id)
			local left = snap.stock[it.id] or 0
			local own = snap.items[it.id] or 0
			local isGear = Data.GEAR[it.id] ~= nil
			local h = wideCard(i, def.icon, def.name, left > 0 and `STOCK x{left} · TIENES {own}` or `AGOTADO · TIENES {own}`, def.desc)
			btn(h, left > 0 and `{UI.fmt(it.cost)} 💩` or "AGOTADO", left > 0 and C.gold or C.grey, function()
				if left > 0 then act("buyItem", it.id) end
			end, left > 0 and it.cost or nil, { Size = UDim2.fromOffset(140, 46) })
			if isGear then
				btn(h, "COLOCAR", own > 0 and C.green or C.grey, function()
					if own > 0 then
						local r = act("placeGear", it.id)
						if r and r.ok then self.close() end
					end
				end, nil, { Size = UDim2.fromOffset(140, 46) })
			end
		end
	end

	function builders.quests()
		useToolbar(true)
		UI.text(toolbar, { Text = snap.questBonus and "✓ ¡Hoy completaste todo!" or "Completa los 3 para un Sobre Legendario 🌟", Size = UDim2.fromScale(1, 1), TextColor3 = C.orange }, 2.5)
		grid(UDim2.fromOffset(760, 110))
		for i, q in snap.quests do
			local done = q.progress >= q.target
			local h = wideCard(i, q.icon, q.title, `PREMIO: {q.reward}`, "", q.progress / q.target)
			btn(h, q.claimed and "✓" or done and "RECLAMAR" or `{UI.fmt(q.progress)}/{UI.fmt(q.target)}`, q.claimed and C.grey or done and C.green or C.panel2, function()
				if done and not q.claimed then act("claimQuest", i) end
			end, nil, { Size = UDim2.fromOffset(140, 56) })
		end
	end

	function builders.index()
		useToolbar(true)
		local found = {}
		for _, id in snap.discovered do found[id] = true end
		UI.text(toolbar, { Text = `📖 DESCUBIERTAS {#snap.discovered}/{#Data.BREEDS}`, Size = UDim2.new(1, -16, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.brown }, 2.5)
		grid(UDim2.fromOffset(136, 170))
		local order = 0
		for i, r in Data.INDEX_REWARDS do
			order += 1
			local claimed = table.find(snap.indexClaimed, i) ~= nil
			local ready = #snap.discovered >= r.n and not claimed
			local card = UI.box(scroll, { LayoutOrder = order }, claimed and C.grey or ready and C.green or C.gold, 16)
			UI.text(card, { Text = `{r.n} RAZAS`, Position = UDim2.fromOffset(6, 8), Size = UDim2.new(1, -12, 0, 24) }, 2.5)
			UI.text(card, { Text = Data.rewardIcon(r.reward), Position = UDim2.fromOffset(20, 36), Size = UDim2.new(1, -40, 0, 60) }, 0)
			UI.text(card, { Text = claimed and "✓" or ready and "¡RECLAMAR!" or Data.rewardText(r.reward, snap.level), Position = UDim2.fromOffset(6, 104), Size = UDim2.new(1, -12, 0, 50), TextWrapped = true }, 2)
			if ready then
				local hit = UI.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, card)
				hit.Activated:Connect(function() act("claimIndex", i) end)
			end
		end
		for _, b in Data.BREEDS do
			order += 1
			local ra = Data.RARITY[b.rarity]
			local card = UI.box(scroll, { LayoutOrder = order }, found[b.id] and UI.light(ra.color, 0.5) or Color3.fromRGB(60, 55, 70), 16)
			if found[b.id] then
				Pets.viewport(card, { breed = b.id, rarity = b.rarity, quality = "gris", age = "adult", mutations = {} }, { Size = UDim2.new(1, 0, 0, 110) })
				UI.text(card, { Text = b.name, Position = UDim2.fromOffset(4, 112), Size = UDim2.new(1, -8, 0, 24), TextColor3 = ra.color }, 2.5)
			else
				UI.text(card, { Text = "?", Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 96), TextColor3 = Color3.fromRGB(120, 110, 140) }, 3)
				UI.text(card, { Text = "???", Position = UDim2.fromOffset(4, 112), Size = UDim2.new(1, -8, 0, 24) }, 2.5)
			end
			UI.text(card, { Text = ra.name, Position = UDim2.fromOffset(4, 138), Size = UDim2.new(1, -8, 0, 20), TextColor3 = ra.color }, 2)
		end
	end

	function builders.codes()
		useToolbar(false)
		grid(UDim2.fromOffset(600, 220))
		local card = UI.box(scroll, {}, UI.light(C.purple, 0.5), 20)
		UI.text(card, { Text = "Busca códigos en nuestras redes 👀", Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -40, 0, 34) }, 2.5)
		local input = UI.new("TextBox", { Text = "", PlaceholderText = "ESCRIBE UN CÓDIGO", FontFace = UI.FONT, TextScaled = true, TextColor3 = C.ink, PlaceholderColor3 = C.grey, ClearTextOnFocus = false, Position = UDim2.fromOffset(40, 64), Size = UDim2.new(1, -80, 0, 56), BackgroundColor3 = C.white }, card)
		UI.corner(input, 12)
		UI.stroke(input, 3, C.ink, true)
		btn(card, "CANJEAR", C.green, function()
			local r = act("redeem", input.Text)
			if r and r.ok then input.Text = "" end
		end, nil, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 136), Size = UDim2.fromOffset(240, 60) })
	end

	local function signature()
		if tab == "codes" then return "codes" end
		if tab == "gear" then
			local s = `gear{snap.gearPlaced}`
			for _, it in Data.SHOP do s ..= `{it.id}{snap.stock[it.id] or 0}{snap.items[it.id] or 0}` end
			return s
		end
		if tab == "rebirth" then
			local s = `rb{snap.rebirths}{snap.tokens}`
			for _, p in Data.PERKS do s ..= (snap.perks[p.id] or 0) end
			return s
		end
		if tab == "parks" then return `pk{snap.zones}{snap.park}` end
		if tab == "quests" then
			local s = `q{tostring(snap.questBonus)}`
			for _, q in snap.quests do s ..= `{q.progress}{tostring(q.claimed)}` end
			return s
		end
		if tab == "index" then return `ix{#snap.discovered}{#snap.indexClaimed}` end
		if tab == "daily" then return `d{snap.daily.can}{snap.daily.streak}{snap.level}` end
		if tab == "gifts" then
			local s = `g{snap.level}`
			for i, g in Data.GIFTS do
				s ..= (table.find(snap.gifts, i) and "c" or (snap.session >= g.t and "r" or "l"))
			end
			return s
		end
		if tab == "dogs" then
			local s = `dogs{snap.capacity}{snap.activeCount}`
			for _, d in snap.dogs do s ..= `{d.id}{d.active and 1 or 0}{d.age}{d.level}{table.concat(d.mutations)}{d.fusion};` end
			return s
		end
		local function dump(t)
			local keys = {}
			for k, v in t do table.insert(keys, `{k}={v}`) end
			table.sort(keys)
			return table.concat(keys, ",")
		end
		return tab .. dump(snap.packs) .. dump(snap.upgrades) .. dump(snap.objects) .. dump(snap.food) .. snap.selectedFood
	end

	function rebuild(force)
		if not (tab and snap and window.Visible) then return end
		local s = signature()
		if s ~= sig or force then
			sig = s
			local keep = scroll.CanvasPosition
			scroll:ClearAllChildren()
			toolbar:ClearAllChildren()
			afford, hungerBars, live = {}, {}, {}
			local t = M.TABS[tab]
			title.Text = t.icon .. " " .. t.title
			UI.setColor(header, t.color)
			builders[tab]()
			scroll.CanvasPosition = keep
			if force then
				local i = 0
				for _, ch in scroll:GetDescendants() do
					if ch:IsA("Frame") and ch:FindFirstChildOfClass("UIStroke") and (ch.Parent == scroll or ch.Parent.Parent == scroll) then
						i += 1
						local sc = ch:FindFirstChild("Pop") or UI.new("UIScale", { Name = "Pop" }, ch)
						sc.Scale = 0
						task.delay(i * 0.035, function()
							TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
						end)
					end
				end
			end
		end
		for _, e in afford do UI.setColor(e[1], snap.poop >= e[2] and e[3] or C.grey) end
		for _, d in snap.dogs do
			local bar = hungerBars[d.id]
			if bar then bar.Size = UDim2.fromScale(d.hunger / 100, 1) end
		end
		for _, f in live do f(snap) end
	end

	-- ficha de un perro: mutaciones, equipar y usar sprays
	local detail, detailId, detailSig
	local function dogSig(d)
		local s = `{d.id}{d.active}{d.age}{d.level}{table.concat(d.mutations)}`
		for id in Data.SPRAYS do s ..= (snap.items[id] or 0) end
		return s
	end
	local function buildDetail(d)
		if detail then detail:Destroy() end
		detailSig = dogSig(d)
		local ra, qu, br = Data.RARITY[d.rarity], Data.QUALITY[d.quality], Data.BREED[d.breed]
		detail = UI.box(window, { Position = UDim2.fromOffset(10, 76), Size = UDim2.new(1, -20, 1, -86), ZIndex = 10 }, C.panel, 18)
		local stage = UI.box(detail, { Position = UDim2.fromOffset(14, 14), Size = UDim2.fromOffset(300, 300) }, UI.light(ra.color, 0.5), 18)
		local _, model = Pets.viewport(stage, d, { Size = UDim2.fromScale(1, 1) })
		local spin = game:GetService("RunService").RenderStepped:Connect(function(dt)
			model:PivotTo(model:GetPivot() * CFrame.Angles(0, dt * 0.8, 0))
		end)
		detail.Destroying:Connect(function() spin:Disconnect() end)
		local x = 334
		UI.text(detail, { Text = br.name, Position = UDim2.fromOffset(x, 12), Size = UDim2.new(1, -x - 20, 0, 44), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = ra.color }, 3)
		UI.text(detail, { Text = `{ra.name} · Calidad {qu.name} · Nv.{d.level} · {AGES[d.age]} {d.sex == "M" and "♂" or "♀"}`, FontFace = UI.BODY, Position = UDim2.fromOffset(x, 58), Size = UDim2.new(1, -x - 20, 0, 24), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.ink }, 0)
		local mlist = {}
		for _, id in d.mutations do
			local mu = Data.MUTATIONS[id]
			table.insert(mlist, `{mu.icon} {mu.name} x{mu.mult}`)
		end
		UI.text(detail, { Text = #mlist > 0 and table.concat(mlist, "   ") or "Sin mutaciones (¡espera el clima!)", Position = UDim2.fromOffset(x, 90), Size = UDim2.new(1, -x - 20, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.purple }, 2)
		UI.text(detail, { Text = `MULTIPLICADOR: x{string.format("%.1f", Data.mutationMult(d.mutations) * Data.fusionMult(d.fusion) * d.size)}  ·  📏 {Data.sizeLabel(d.size)} {d.size}  {d.fusion > 0 and Data.FUSION.Stars[d.fusion] or ""}`, Position = UDim2.fromOffset(x, 124), Size = UDim2.new(1, -x - 20, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.gold }, 2.5)
		btn(detail, d.active and "GUARDAR" or "EQUIPAR", d.active and C.grey or C.green, function()
			act(d.active and "deactivate" or "activate", d.id)
		end, nil, { Position = UDim2.fromOffset(x, 166), Size = UDim2.fromOffset(200, 54) })
		local sprays = UI.new("Frame", { Position = UDim2.fromOffset(x, 232), Size = UDim2.new(1, -x - 20, 0, 60), BackgroundTransparency = 1 }, detail)
		UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }, sprays)
		for id, sp in Data.SPRAYS do
			local n = snap.items[id] or 0
			if n > 0 then
				btn(sprays, `{sp.icon} x{n}`, C.purple, function() act("useSpray", d.id, id) end, nil, { Size = UDim2.fromOffset(110, 54) })
			end
		end
		btn(detail, "◀ VOLVER", C.blue, function() self.closeDog() end, nil, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(170, 52) })
	end
	function self.showDog(id)
		detailId = id
		for _, d in snap.dogs do
			if d.id == id then buildDetail(d) end
		end
	end
	function self.closeDog()
		if detail then detail:Destroy() end
		detail, detailId = nil, nil
	end
	local function refreshDetail()
		if not detailId then return end
		for _, d in snap.dogs do
			if d.id == detailId then
				if dogSig(d) ~= detailSig then buildDetail(d) end
				return
			end
		end
		self.closeDog()
	end

	-- el encabezado usa el mismo degradado que los botones
	header.UIGradient.Name = "Fill"

	function self.open(t)
		if window.Visible and tab == t then return self.close() end
		tab, sig = t, nil
		fuseMode, fuseSel = false, {}
		self.closeDog()
		window.Visible = true
		scroll.CanvasPosition = Vector2.zero
		local base = wscale.Scale
		wscale.Scale = base * 0.85
		TweenService:Create(wscale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = base }):Play()
		rebuild(true)
	end
	function self.close() window.Visible = false end
	function self.tab() return window.Visible and tab or nil end
	function self.update(s)
		snap, snapAt = s, os.clock()
		rebuild(false)
		if window.Visible then refreshDetail() end
	end
	return self
end

return M
