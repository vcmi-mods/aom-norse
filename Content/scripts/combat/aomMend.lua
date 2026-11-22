-- Heal adjacent allies at the start of each round (automatons repairing each other, Caladria healing).
-- val = healing (per healer; a stack heals val x stack size)
-- addInfo (only for description and checks; actual healing uses the hidden markers on the creature, see Script:mend):
--   mechanicalOnly  repairs non-living units only (Automaton Warriors)
--   resurrect       leftover healing revives dead units (Green-Plume Seers)
--   look            visuals: Atlantean by default; "norse" uses the Norse Valkyrie ones (kind 4 heal, 5 heal with resurrection)
local Base = require("combat/combatScript")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

-- Animations only in real battles: sending animation packs during AI evaluation (describeChanges false) makes the engine log "BattleAnimationPlayed is not allowed in battle evaluation" every time
local function showAnim(server, ...)
	if server.describeChanges and not server:describeChanges() then return end
	server:showBattleAnimation(...)
end

local function oblivion(unit)
	local ok, has = pcall(function() return unit:hasBonuses({ type = "HOTA_RING_OF_OBLIVION" }) end)
	return ok and has
end

local MENDER, KIND = "AOM_MENDER", "AOM_MEND_KIND"
-- The Atlantean and Norse mods each define these two markers; with both installed an unprefixed name does not resolve (the engine looks it up globally and two of the same name fail),
-- so each mod prefix is read separately and the largest value taken (a unit only carries one mod's marker); the prefix of a mod that is not installed falls back to the same-named marker of the installed one,
-- so adding them would double the value (double healing, kind 8 with no animation) - hence the maximum, not the sum. Healers of both mods are still settled once by the same leading unit.
local SCOPES = { "aom-atlantean:", "aom-norse:" }
local function marker(u, name)
	local v = 0
	for _, s in ipairs(SCOPES) do
		local ok, x = pcall(function() return u:getBonusesValue({ type = s .. name }) end)
		if ok and x > v then v = x end
	end
	return v
end
local ANIMATION = { "aom/atlantean/fx/heal.json", "aom/atlantean/fx/repair.json", "aom/atlantean/fx/revive.json", "aom/nor/fx/nvHeal.json", "aom/nor/fx/nvRevive.json" }

--- one healer heals its adjacent allies; healed targets go into `shown` (by unit id, one visual per target)
local function mendOne(server, battle, healer, shown)
	local side = healer:getSide()
	local kind = marker(healer, KIND)          -- 1 heal, 2 repair mechanical only, 3 heal with resurrection; 4, 5 = heal / heal with resurrection with Norse visuals
	local power = marker(healer, MENDER) * healer:getCount()
	local seen = {}

	local hexes = healer:getSurroundingHexes()
	for i = 1, hexes:size() do
		local other = battle:getUnitByPos(hexes:at(i), true)
		if other and other:isAlive() and other:getSide() == side and other:unitID() ~= healer:unitID() and not seen[other:unitID()] then
			seen[other:unitID()] = true
			local wanted = kind ~= 2 or other:hasBonuses({ type = "NON_LIVING" }) or other:hasBonuses({ type = "MECHANICAL" })
			-- with the Ring of Oblivion (HotA) in play no resurrection: plain healing of the top creature only (as in HotA's ringOfOblivionPatch.lua; without HotA the bonus type does not exist, hence pcall)
			local revive = (kind == 3 or kind == 5) and not oblivion(other)
			local hurt = other:getFirstHPleft() < other:getMaxHealth() or (revive and other:getCount() < other:getBaseAmount())
			if wanted and hurt then
				local amount = power
				if not revive then amount = math.min(power, other:getMaxHealth() - other:getFirstHPleft()) end
				if amount > 0 then
					-- the engine rejects "heal only + one battle" (Heal for one battle does not make sense), so healing is permanent; resurrected units vanish after the battle
					server:healUnit(battle, other, amount, revive and ENUM.HealLevel.resurrect or ENUM.HealLevel.heal, revive and ENUM.HealPower.oneBattle or ENUM.HealPower.permanent)
					-- one visual per target: if several healers reach it in a round, keep the strongest (revive > heal > repair), so two visuals never stack on one unit or one plays twice
					local id, what = other:unitID(), kind
					local rank = { [2] = 1, [1] = 2, [4] = 2, [3] = 3, [5] = 3 }
					if shown[id] == nil or rank[what] > rank[shown[id].kind] then shown[id] = { unit = other, kind = what } end
				end
			end
		end
	end
end

--- At round start the lowest-id healer of a side settles all of that side's healing at once, playing each visual once and together (one per healer would queue up and take seconds every round with many healers).
--- Other healers' amount and kind come from their hidden AOM_MENDER (amount) and AOM_MEND_KIND (kind), so every creature with this script must carry both markers (added by tools/abilities.py).
function Script:mend(server, battle, unit)
	if not unit:isAlive() then return end
	local side = unit:getSide()
	local healers = battle:getUnitsIf(function(u) return u:isAlive() and u:getSide() == side and marker(u, MENDER) > 0 end)
	for _, healer in ipairs(healers) do
		if healer:unitID() < unit:unitID() then return end          -- not the leader
	end
	table.sort(healers, function(a, b) return a:unitID() < b:unitID() end)

	local shown = {}
	for _, healer in ipairs(healers) do mendOne(server, battle, healer, shown) end
	local lists = { {}, {}, {}, {}, {} }
	for _, entry in pairs(shown) do
		local list = lists[entry.kind]
		list[#list + 1] = { unit = entry.unit }
	end

	-- Visuals use the original game effects: heal = Caladria_healing (cyan light pillar), repair = automaton_heal (sparks), with resurrection = Caladria_burst_healing (white pillar and halo);
	-- Norse Valkyrie = valkyrie_heal (cyan-white orb) plus valkyrie_heal_pulse (halo); with resurrection the orb is white-gold with two halos
	local any = false
	for kind = 1, #ANIMATION do
		if #lists[kind] > 0 then
			showAnim(server, battle, lists[kind], ANIMATION[kind], any and "" or "CURE", 1.0, true)
			any = true
		end
	end
	if any then server:refreshBattleUnits(battle) end
end

function Script:onRoundStart(server, battle, unit, other)
	self:mend(server, battle, unit)
end

return Script
