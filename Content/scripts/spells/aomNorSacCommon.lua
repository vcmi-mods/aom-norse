-- Shared part of Soul Offering (Norse racial secondary skill aomNorSacrifice), used by all Norse god-power spells.
-- The skill gives the hero a hidden AOM_NOR_SACRIFICE (at most this percentage of one Einherjar tier is spent: 25 / 50 / 75), inherited by the army; Sorcery synergy AOM_NOR_SAC_CAP (cap +10% more),
-- Warband Oath synergy AOM_NOR_SAC_OATH (stacks in formation get +2 Attack this round after an offering). Einherjar, Ragnarok and round bookkeeping are in combat/aomNorWarband.lua.
-- The first effect of every Norse god power is aomNorSacrifice (key aSac, sorted first by key): it computes this cast's bonus percentage
-- and stores it on the hidden AOM_NOR_SAC_NOW of every unit of the casting side; the later effects (aomNorDamage / aomNorSummon / aomNorTimed / aomNorDot / aomNorHeal) read it to scale.
local M = {}
local SOULS, LEVEL, SEEN, RAGNAROK = "AOM_NOR_SOULS", "AOM_NOR_HERO_LEVEL", "AOM_NOR_WB_SEEN", "AOM_NOR_RAGNAROK"
local NOW = "AOM_NOR_SAC_NOW"
local PER_LEVEL = 60      -- same as the perLevel default in aomNorWarband

local function own(battle, side)
	return battle:getUnitsIf(function(u) return u:isAlive() and u:getSide() == side end)
end
local function maxOf(units, t)
	local v = 0
	for _, u in ipairs(units) do v = math.max(v, u:getBonusesValue({ type = t })) end
	return v
end
local function setAll(server, battle, units, t, value, hidden)
	for _, u in ipairs(units) do
		local old = u:getBonuses({ type = t })
		if old:size() > 0 then server:removeUnitBonuses(battle, u, old) end
		if value > 0 then
			server:addUnitBonus(battle, u, { type = t, sourceType = ENUM.BonusSource.other, val = value,
				valueType = ENUM.BonusValueType.baseNumber, duration = ENUM.BonusDuration.oneBattle, hidden = hidden }, false)
		end
	end
end

--- bonus percentage of this cast (computed by aSac)
function M.boost(mechanics)
	return maxOf(own(mechanics:getBattle(), mechanics:getCasterSide()), NOW)
end
function M.scale(mechanics, value)
	local b = M.boost(mechanics)
	if b <= 0 then return value end
	return math.floor(value * (100 + b) / 100)
end

--- on casting, spend Einherjar and record the bonus. Only settled in real battles (describeChanges true) and when cast by a hero.
function M.consume(mechanics, server)
	if not server:describeChanges() then return end
	local battle, side = mechanics:getBattle(), mechanics:getCasterSide()
	local units = own(battle, side)
	if #units == 0 then return end
	local share = mechanics:getHeroCaster() and maxOf(units, "AOM_NOR_SACRIFICE") or 0
	if share <= 0 then setAll(server, battle, units, NOW, 0, true) return end
	local cap = math.floor(share * 6 / 10) + maxOf(units, "AOM_NOR_SAC_CAP")
	local souls = maxOf(units, SOULS)
	local want = math.max(1, math.floor(math.max(1, maxOf(units, LEVEL)) * PER_LEVEL * share / 100))
	local boost, used, free = 0, 0, false
	local rag = maxOf(units, RAGNAROK)
	if rag > 0 and rag == maxOf(units, SEEN) then      -- the Ragnarok round: nothing is spent, the cap is used
		boost, free = cap, true
	else
		used = math.min(souls, want)
		boost = math.floor(cap * used / want)
		if used > 0 then setAll(server, battle, units, SOULS, souls - used, false) end
	end
	setAll(server, battle, units, NOW, boost, true)
	if boost <= 0 then return end
	if free then
		server:appendLog(battle, { append = { "core.bonus.AOM_NOR_SACRIFICE.description.2" }, replaceStrings = { mechanics:getSpell():getNameTextID() }, replaceNumbers = { boost } })
	else
		server:appendLog(battle, { append = { "core.bonus.AOM_NOR_SACRIFICE.description.1" }, replaceStrings = { mechanics:getSpell():getNameTextID() }, replaceNumbers = { used, boost } })
	end
	-- Warband Oath synergy: stacks in formation (with Shield Wall or Svinfylking) get +2 Attack this round
	local atk = maxOf(units, "AOM_NOR_SAC_OATH")
	if atk > 0 then
		for _, u in ipairs(units) do
			if u:hasBonuses({ type = "AOM_NOR_SHIELDWALL" }) or u:hasBonuses({ type = "AOM_NOR_SVINFYLKING" }) then
				server:addUnitBonus(battle, u, { type = "PRIMARY_SKILL", subtype = "primarySkill.attack", val = atk, duration = ENUM.BonusDuration.nTurns, turns = 1,
					hidden = true, sourceType = ENUM.BonusSource.other, valueType = ENUM.BonusValueType.additiveValue }, false)
			end
		end
	end
end

--- the casting hero's major god (hidden AOM_NOR_GOD, inherited by the army: 1 Thor 2 Odin 3 Loki 4 Freyr) is in effect.gods
function M.favoured(effect, mechanics)
	if not mechanics:getHeroCaster() or not effect.gods then return false end
	local g = maxOf(own(mechanics:getBattle(), mechanics:getCasterSide()), "AOM_NOR_GOD")
	for _, want in ipairs(effect.gods) do
		if want == g then return true end
	end
	return false
end

--- units of our / the enemy whole army that pass the filter
local LIVING_NOT = { "NON_LIVING", "MECHANICAL", "UNDEAD", "SIEGE_WEAPON" }
function M.shortKey(unit)
	local key = unit:getCreature():getJsonKey()
	key = key:match("([^:]+)$") or key
	return key:match("^kad%a+_aom_norse_(.+)$") or key
end
--- capital guardians (kad-mechanics: hidden LUCK 0, stacking group kadGuardian)
function M.isGuardian(unit)
	local l = unit:getBonuses({ type = "LUCK" })
	for i = 1, l:size() do if l:getBonus(i):getStacking() == "kadGuardian" then return true end end
	return false
end
function M.passes(filter, unit)
	if filter == nil then return not unit:hasBonuses({ type = "SIEGE_WEAPON" }) end
	if filter == "living" then
		for _, t in ipairs(LIVING_NOT) do if unit:hasBonuses({ type = t }) then return false end end
		return true
	elseif filter == "lines" then
		local k = M.shortKey(unit)
		return k:match("^aomNorBerserk") ~= nil or k:match("^aomNorAxeman") ~= nil
	elseif filter == "siege" then
		return unit:hasBonuses({ type = "SIEGE_WEAPON" }) and not unit:isTurret()
	elseif filter == "noBoss" then      -- control effects (freezing) do not affect war machines, commanders or capital guardians
		return not unit:hasBonuses({ type = "SIEGE_WEAPON" }) and not unit:isCommander() and not M.isGuardian(unit)
	elseif filter == "notFlying" then
		return not unit:hasBonuses({ type = "FLYING" }) and not unit:hasBonuses({ type = "SIEGE_WEAPON" })
	end
	return true
end
function M.massTarget(effect, mechanics, which)
	local battle, side, out = mechanics:getBattle(), mechanics:getCasterSide(), {}
	for _, u in ipairs(battle:getUnitsIf(function(u)
		if not u:isAlive() then return false end
		if which == "own" and u:getSide() ~= side then return false end
		if which == "enemy" and u:getSide() == side then return false end
		return M.passes(effect.filter, u) and effect:isValidTarget(mechanics, u) and effect:isReceptive(mechanics, u)
	end)) do
		out[#out + 1] = { unit = u, hex = u:getPosition() }
	end
	return out
end

return M
