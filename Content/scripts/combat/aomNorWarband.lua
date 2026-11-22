-- Einherjar Warband: the Norse faction system (only for troops led by heroes of the Norse classes).
-- Setup: a hidden COMBAT_EVENT_TRIGGER aomNorWarband in every Norse hero's specialty (inherited by the whole army); the hero level comes from
-- AOM_NOR_HERO_LEVEL (TIMES_HERO_LEVEL) in the same specialty; the racial skill Warband Oath gives the hero AOM_NOR_OATH = 1/2/3 (Basic/Advanced/Expert).
--
-- 1. Warband formations (recomputed from positions at each round start, last that round)
--   Shield Wall: a stack of the Berserker or Axeman line with at least one friendly stack of those two lines adjacent in front, behind or to the side -> ranged damage taken -15%
--   Svinfylking: both diagonal hexes behind a stack (toward our side) hold friendly units -> melee damage +20%
--   Warband Oath: formation effects x1.25 / x1.5 / x2
-- 2. Valhalla
--   Our fallen troops add their health to Einherjar, enemies we kill add half their health; Warband Oath +20% / 40% / 60%, each star of Odin's Wain +10%.
--   Each full tier of Einherjar (hero level x 60) recalls a stack of Einherjar Warriors (count = tier / Einherjar Warrior health), at most 3 times per battle.
--   Deaths caused by spells and field effects (moat, poison) do not count (the engine sends no "after attack" event for them).
-- 3. Odin's Wain
--   At battle start one star lights up per distinct level of Norse creatures in the army (1-7 stars, summons do not count).
--   Yggdrasil (Grail, Roots of the Nine Worlds): Norse heroes of the whole kingdom start battles with 2 more stars (AOM_NOR_STAR_BONUS) and +25% Einherjar (AOM_NOR_SOUL_BONUS).
--   With enough stars (7 stars; 7 / 6 / 5 with Basic / Advanced / Expert Warband Oath), Ragnarok triggers once from round 7 on:
--   our Norse troops deal +30% damage that round, and one more stack of Einherjar Warriors is recalled (not counted against the 3).
--
-- 4. Town buildings (when defending a town they are on the defending hero; town bonuses have no propagator)
--   Valhalla: recall threshold halved (AOM_NOR_VALHALLA = percent reduction). Gjallarhorn: Einherjar start the battle with half a tier (AOM_NOR_HORN = percent).
--   Mythic and Wonder Age: +10% Einherjar in town defense (AOM_NOR_SOUL_BONUS, same type as the Grail, added together).
-- A side's state is stored on all units of that side that have the script (hidden counters), so nothing is lost when one dies; each round the first unit of the side to trigger settles it once (as with Favor).
-- Einherjar and stars are not shown on war machines. Battle log: at battle start the number of stars and the round of Ragnarok (or how many stars are missing),
-- and in rounds where the Einherjar points or recall count changed one line "Einherjar N/M, recalled n/3" (stops after 3 recalls).
local Base = require("combat/combatScript")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local SEEN, TICK = "AOM_NOR_WB_SEEN", "AOM_NOR_WB_TICK"
local SOULS, CALLS, STARS, RAGNAROK = "AOM_NOR_SOULS", "AOM_NOR_SOUL_CALLS", "AOM_NOR_STARS", "AOM_NOR_RAGNAROK"
local SOULS_LOG = "AOM_NOR_SOULS_LOG"      -- Einherjar progress last written to the log (points x 4 + count + 1)
local WALL, BOAR = "AOM_NOR_SHIELDWALL", "AOM_NOR_SVINFYLKING"
local OATH, LEVEL = "AOM_NOR_OATH", "AOM_NOR_HERO_LEVEL"
local EINHERI = "aom-norse:aomNorEinheri"
local MAX_CALLS = 3
local RAGNAROK_ROUND = 7
local FORM_MULT = { [0] = 1.0, 1.25, 1.5, 2.0 }
local SOUL_BONUS = { [0] = 0, 20, 40, 60 }
local STARS_NEED = { [0] = 7, 7, 6, 5 }
local CALL_FX = "aom/nor/fx/spEinherjar.json"
local STAR_BONUS, SOUL_BONUS_T, VALHALLA, HORN = "AOM_NOR_STAR_BONUS", "AOM_NOR_SOUL_BONUS", "AOM_NOR_VALHALLA", "AOM_NOR_HORN"

local function real(server) return not server.describeChanges or server:describeChanges() end

local function shortKey(unit)
	local key = unit:getCreature():getJsonKey()
	key = key:match("([^:]+)$") or key
	return key:match("^kad%a+_aom_norse_(.+)$") or key
end

local function setValue(server, battle, unit, bonusType, value, hidden)
	hidden = hidden or unit:hasBonuses({ type = "SIEGE_WEAPON" }) or shortKey(unit):match("^aomNorRam") ~= nil
	local old = unit:getBonuses({ type = bonusType })
	if old:size() > 0 then server:removeUnitBonuses(battle, unit, old) end
	if value > 0 then
		server:addUnitBonus(battle, unit, { type = bonusType, sourceType = ENUM.BonusSource.other, val = value,
			valueType = ENUM.BonusValueType.baseNumber, duration = ENUM.BonusDuration.oneBattle, hidden = hidden }, false)
	end
end

local function isNorse(unit) return shortKey(unit):match("^aomNor") ~= nil end
local function isLine(unit)
	local k = shortKey(unit)
	return k:match("^aomNorBerserk") ~= nil or k:match("^aomNorAxeman") ~= nil
end
local function fighting(u) return u:isAlive() and not u:isTurret() and not u:hasBonuses({ type = "SIEGE_WEAPON" }) and not shortKey(u):match("^aomNorRam") end

--- all living units of this side (the script is on the hero, so the whole army has it)
local function sideUnits(battle, side)
	return battle:getUnitsIf(function(u) return u:isAlive() and u:getSide() == side end)
end
local function sideMax(units, bonusType)
	local best = 0
	for _, u in ipairs(units) do best = math.max(best, u:getBonusesValue({ type = bonusType })) end
	return best
end
local function sideSet(server, battle, units, bonusType, value, hidden)
	for _, u in ipairs(units) do setValue(server, battle, u, bonusType, value, hidden) end
end

--- a newly arrived unit (recalled Einherjar Warriors) takes over this side's bookkeeping, so the tally is not lost when the original troops are all dead
local SIDE_STATE = { { TICK, true }, { SOULS, false }, { CALLS, true }, { STARS, false }, { RAGNAROK, true } }
local function sideSync(server, battle, side)
	local units = battle:getUnitsIf(function(u) return u:isAlive() and u:getSide() == side end)
	for _, st in ipairs(SIDE_STATE) do
		local v = sideMax(units, st[1])
		for _, u in ipairs(units) do
			if v > 0 and u:getBonusesValue({ type = st[1] }) ~= v then setValue(server, battle, u, st[1], v, st[2]) end
		end
	end
	return units
end

--- full-battlefield animations always deferred (6th argument true): at battle start the kad battlefield sigil animation is still playing, and playing at once makes the client log Unexpected animations state
--- the full-battlefield animation of Odin's Wain (Big Dipper) plays on hex (8,10) of the bottom row: the image is 820x1012 with the battlefield at the top left; the engine centres the image on the top edge of that hex, so the whole image lines up with the battlefield
--- (same technique as the full-battlefield animation of Return to Atlantis, see aomReturnLib.lua)
local function screenHex(battle)
	local arr = battle:getAllPossibleHexes()
	for i = 1, arr:size() do
		local h = arr:at(i)
		if h:getY() == 10 and h:getX() == 8 then return h end
	end
	return nil
end

local function friendAt(battle, hex, side, self)
	if hex == nil or not hex:isValid() then return nil end
	local u = battle:getUnitByPos(hex, true)
	if u ~= nil and u:isAlive() and u:getSide() == side and u:unitID() ~= self:unitID() then return u end
	return nil
end

--- the two diagonal hexes behind a stack (toward our side). Two-hex units count from the rear hex.
local function behind(unit)
	local pos = unit:getPosition()
	local wide = unit:getCreature():isDoubleWide()
	if unit:getSide() == ENUM.BattleSide.attacker then
		if wide then pos = pos:copyToWest() end
		return pos:copyToNorthWest(), pos:copyToSouthWest()
	else
		if wide then pos = pos:copyToEast() end
		return pos:copyToNorthEast(), pos:copyToSouthEast()
	end
end

local function buff(server, battle, u, bonus)
	bonus.sourceType = ENUM.BonusSource.other
	bonus.valueType = bonus.valueType or ENUM.BonusValueType.additiveValue
	server:addUnitBonus(battle, u, bonus, false)
end

function Script:formations(server, battle, units, oath)
	local mult = FORM_MULT[oath] or 1.0
	-- Warband Oath synergies: Armorer +5% more Shield Wall, Leadership +1 Morale for stacks in formation
	local wall = math.floor(15 * mult + 0.5) + sideMax(units, "AOM_NOR_OATH_ARMOR")
	local boar = math.floor(20 * mult + 0.5)
	local morale = sideMax(units, "AOM_NOR_OATH_MORALE")
	local walls, boars = {}, {}
	for _, u in ipairs(units) do
		if fighting(u) then
			local side = u:getSide()
			if isLine(u) then
				local arr = u:getSurroundingHexes()
				for i = 1, arr:size() do
					local f = friendAt(battle, arr:at(i), side, u)
					if f ~= nil and isLine(f) then walls[#walls + 1] = u break end
				end
			end
			local a, b = behind(u)
			if friendAt(battle, a, side, u) ~= nil and friendAt(battle, b, side, u) ~= nil then boars[#boars + 1] = u end
		end
	end
	for _, u in ipairs(walls) do
		buff(server, battle, u, { type = "GENERAL_DAMAGE_REDUCTION", subtype = "damageTypeRanged", val = wall, duration = ENUM.BonusDuration.nTurns, turns = 1, hidden = true })
		buff(server, battle, u, { type = WALL, val = wall, valueType = ENUM.BonusValueType.baseNumber, duration = ENUM.BonusDuration.nTurns, turns = 1 })
	end
	for _, u in ipairs(boars) do
		buff(server, battle, u, { type = "PERCENTAGE_DAMAGE_BOOST", subtype = "damageTypeMelee", val = boar, duration = ENUM.BonusDuration.nTurns, turns = 1, hidden = true })
		buff(server, battle, u, { type = BOAR, val = boar, valueType = ENUM.BonusValueType.baseNumber, duration = ENUM.BonusDuration.nTurns, turns = 1 })
	end
	if morale > 0 then
		local done = {}
		for _, list in ipairs({ walls, boars }) do
			for _, u in ipairs(list) do
				if not done[u:unitID()] then
					done[u:unitID()] = true
					buff(server, battle, u, { type = "MORALE", val = morale, duration = ENUM.BonusDuration.nTurns, turns = 1, hidden = true })
				end
			end
		end
	end
	if real(server) and (#walls > 0 or #boars > 0) then
		local fx = {}
		for _, u in ipairs(walls) do fx[#fx + 1] = { unit = u } end
		for _, u in ipairs(boars) do fx[#fx + 1] = { unit = u } end
		server:showBattleAnimation(battle, fx, "aom/nor/fx/fxRuneCircle.json", "", 0.9, true)
		server:appendLog(battle, { append = { "core.bonus." .. WALL .. ".description.1" }, replaceNumbers = { #walls, #boars } })
	end
end

--- recall a stack of Einherjar Warriors (count = this tier's Einherjar / Einherjar Warrior health, at least 1)
local function callEinheri(server, battle, side, souls, logKey)
	local creature = LIBRARY:getCreatureByName(EINHERI)
	if creature == nil then return end
	local count = math.max(1, math.floor(souls / creature:getMaxHealth()))
	local hex = battle:getAvailableHex(creature, side)
	if not hex:isValid() then return end
	server:addUnit(battle, { count = count, type = creature, side = side, position = hex, summoned = true })
	if real(server) then
		local u = battle:getUnitByPos(hex, true)
		if u ~= nil then server:showBattleAnimation(battle, { { unit = u } }, CALL_FX, "BLESS", 1.0, true) end
		server:refreshBattleUnits(battle)
		server:appendLog(battle, { append = { "core.bonus." .. SOULS .. ".description." .. logKey }, replaceStrings = { creature:getNameTextID(count) }, replaceNumbers = { count } })
	end
end

function Script:threshold(unit)
	return math.max(1, unit:getBonusesValue({ type = LEVEL })) * (self.perLevel or 60)
end

--- Einherjar needed for the next recall: the 1st, 2nd and 3rd need 100%, 150% and 200% of a tier; Valhalla halves it in town defense
function Script:need(unit, units, calls)
	local cut = math.min(90, math.max(0, sideMax(units, VALHALLA)))
	return math.max(1, math.floor(self:threshold(unit) * (2 + calls) / 2 * (100 - cut) / 100))
end

--- add Einherjar, recall when a tier is full
function Script:addSouls(server, battle, unit, hp)
	if hp <= 0 then return end
	local side = unit:getSide()
	local units = sideUnits(battle, side)
	if #units == 0 then return end
	local oath = sideMax(units, OATH)
	local stars = sideMax(units, STARS)
	local odin = math.min(50, sideMax(units, "AOM_NOR_ODIN"))      -- Odin's specialty "Einherjar Call"
	local extra = math.max(0, sideMax(units, SOUL_BONUS_T))      -- Yggdrasil, ages in town defense
	local gained = math.floor(hp * (100 + (SOUL_BONUS[oath] or 0) + 5 * stars + odin + extra) / 100)
	local souls = sideMax(units, SOULS) + gained
	local calls = sideMax(units, CALLS)
	-- the threshold rises each time: the 1st, 2nd and 3rd recall need 100%, 150% and 200% of a tier (a tier = hero level x 60); each recall brings one tier's worth
	local base = self:threshold(unit)
	local need = self:need(unit, units, calls)      -- Valhalla: threshold halved in town defense (recall size unchanged)
	if calls < MAX_CALLS and souls >= need then
		souls = souls - need
		calls = calls + 1
		sideSet(server, battle, units, CALLS, calls, true)
		need = base
		callEinheri(server, battle, side, need, 1)
		if calls == 1 and odin > 0 then callEinheri(server, battle, side, need, 1) end      -- Einherjar Call: one more stack on the first recall
		units = sideSync(server, battle, side)
	end
	sideSet(server, battle, units, SOULS, souls, false)
end

-- our troop died: add its health
function Script:onAfterAttacked(server, battle, unit, other, payload)
	local e = self:ownEntry(unit, payload)
	if e == nil or (e.killed or 0) <= 0 then return end
	self:addSouls(server, battle, unit, e.killed * unit:getMaxHealth())
end

-- we killed an enemy: add half its health
function Script:onAfterAttack(server, battle, unit, other, payload)
	local side = unit:getSide()
	local hp = 0
	for _, t in ipairs(payload.targets or {}) do
		if t.unit ~= nil and t.unit:getSide() ~= side and (t.killed or 0) > 0 then hp = hp + t.killed * t.unit:getMaxHealth() end
	end
	self:addSouls(server, battle, unit, math.floor(hp / 2))
end

function Script:startOfRound(server, battle, unit)
	local seen = unit:getBonusesValue({ type = SEEN }) + 1
	setValue(server, battle, unit, SEEN, seen, true)
	local side = unit:getSide()
	local units = sideUnits(battle, side)
	if seen <= sideMax(units, TICK) then return end
	sideSet(server, battle, units, TICK, seen, true)
	local oath = sideMax(units, OATH)
	if seen == 1 then
		-- Odin's Wain: light one star per distinct level of Norse creatures at battle start
		local levels, n = {}, 0
		for _, u in ipairs(units) do
			if not u:isSummoned() and isNorse(u) then
				local lv = u:creatureLevel()
				if lv >= 1 and lv <= 7 and not levels[lv] then levels[lv] = true n = n + 1 end
			end
		end
		n = math.min(7, n + math.max(0, sideMax(units, STAR_BONUS)))      -- Yggdrasil: 2 more stars
		sideSet(server, battle, units, STARS, n, false)
		local horn = math.min(100, math.max(0, sideMax(units, HORN)))      -- Gjallarhorn: in town defense Einherjar start with half a tier
		if horn > 0 and sideMax(units, SOULS) == 0 then sideSet(server, battle, units, SOULS, math.floor(self:threshold(unit) * horn / 100), false) end
		if real(server) and n > 0 then
			local hex = screenHex(battle)
			if hex then server:showBattleAnimation(battle, { { hex = hex } }, "aom/nor/fx/dipper" .. n .. ".json", "", 1.0, true) end
			local needStars = STARS_NEED[oath] or 7
			if n >= needStars then
				server:appendLog(battle, { append = { "core.bonus." .. STARS .. ".description.2" }, replaceNumbers = { n, RAGNAROK_ROUND } })
			else
				server:appendLog(battle, { append = { "core.bonus." .. STARS .. ".description.3" }, replaceNumbers = { n, needStars } })
			end
		end
	end
	self:formations(server, battle, units, oath)
	-- Ragnarok
	if seen >= RAGNAROK_ROUND and sideMax(units, RAGNAROK) == 0 and sideMax(units, STARS) >= (STARS_NEED[oath] or 7) then
		sideSet(server, battle, units, RAGNAROK, seen, true)      -- remember the round it triggered: Soul Offering costs no Einherjar that round
		local fx = {}
		for _, u in ipairs(units) do
			if isNorse(u) and fighting(u) then
				buff(server, battle, u, { type = "PERCENTAGE_DAMAGE_BOOST", subtype = "damageTypeAll", val = 30, duration = ENUM.BonusDuration.nTurns, turns = 1, hidden = true })
				fx[#fx + 1] = { unit = u }
			end
		end
		if real(server) then
			local hex = screenHex(battle)
			if hex then server:showBattleAnimation(battle, { { hex = hex } }, "aom/nor/fx/dipperRagnarok.json", "", 1.0, true) end
			server:appendLog(battle, { append = { "core.bonus." .. RAGNAROK .. ".description.1" } })
		end
		callEinheri(server, battle, side, self:threshold(unit), 2)
		sideSync(server, battle, side)
	end
	-- Einherjar progress: written only in rounds where the points or recall count changed
	local calls, souls = sideMax(units, CALLS), sideMax(units, SOULS)
	local mark = souls * 4 + calls + 1
	if real(server) and calls < MAX_CALLS and sideMax(units, SOULS_LOG) ~= mark then
		sideSet(server, battle, units, SOULS_LOG, mark, true)
		server:appendLog(battle, { append = { "core.bonus." .. SOULS .. ".description.9" },
			replaceNumbers = { souls, self:need(unit, units, calls), calls } })
	end
	server:refreshBattleUnits(battle)
end

function Script:onBattleStart(server, battle, unit, other)
	if not unit:isAlive() then return end
	self:startOfRound(server, battle, unit)
end

function Script:onRoundStart(server, battle, unit, other)
	if not unit:isAlive() then return end
	self:startOfRound(server, battle, unit)
end

return Script
