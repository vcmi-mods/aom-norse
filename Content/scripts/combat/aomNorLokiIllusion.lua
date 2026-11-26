-- Trickster's Illusion: Loki's creative specialty. At battle start an illusion of the enemy stack with the highest total health (level 7 and above excluded) fights for us,
-- count 10% of that stack + 1% per hero level (at most 35%; none if under 1); the illusion vanishes on any damage. Commanders, capital guardians and war machines are not copied.
-- Setup: COMBAT_EVENT_TRIGGER in the hero specialty (inherited by the whole army and by the illusion too, so it handles "vanish when hurt" itself);
-- the hero level comes from AOM_NOR_HERO_LEVEL (TIMES_HERO_LEVEL) in the same specialty.
local Base = require("combat/combatScript")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local DONE, ILLUSION, LEVEL = "AOM_NOR_ILLUSION_DONE", "AOM_NOR_ILLUSION", "AOM_NOR_HERO_LEVEL"
local FX, FX_OUT = "aom/nor/fx/hxIllusionIn.json", "aom/nor/fx/hxIllusionOut.json"      -- purple beam and halo of the original traitor; vanishing is a purple vortex

--- capital guardians: their creature config has a hidden LUCK 0 in stacking group kadGuardian (kadGuardian.lua of kad-mechanics)
local function isGuardian(u)
	local l = u:getBonuses({ type = "LUCK" })
	for i = 1, l:size() do if l:getBonus(i):getStacking() == "kadGuardian" then return true end end
	return false
end

local function mark(server, battle, unit, bonusType, value, hidden)
	server:addUnitBonus(battle, unit, { type = bonusType, sourceType = ENUM.BonusSource.other, val = value,
		valueType = ENUM.BonusValueType.baseNumber, duration = ENUM.BonusDuration.oneBattle, hidden = hidden }, false)
end

function Script:onBattleStart(server, battle, unit, other)
	if not unit:isAlive() or unit:copy():isSummoned() then return end
	local side = unit:getSide()
	local own = battle:getUnitsIf(function(u) return u:getSide() == side end)
	for _, u in ipairs(own) do
		if u:hasBonuses({ type = DONE }) then return end
	end
	for _, u in ipairs(own) do mark(server, battle, u, DONE, 1, true) end

	local level = math.max(1, unit:getBonusesValue({ type = LEVEL }))
	local pct = math.min(self.max or 35, (self.base or 10) + (self.perLevel or 1) * level)
	local best, bestHp
	for _, e in ipairs(battle:getUnitsIf(function(u) return u:isAlive() and u:getSide() ~= side and not u:isGhost() and not u:isTurret() end)) do
		if not e:hasBonuses({ type = "SIEGE_WEAPON" }) and not e:isCommander() and not isGuardian(e) and e:getCreature():getLevel() < 7
			and math.floor(e:getCount() * pct / 100) >= 1 then
			local hp = (e:getCount() - 1) * e:getMaxHealth() + e:getFirstHPleft()
			if not best or hp > bestHp then best, bestHp = e, hp end
		end
	end
	if not best then return end
	local count = math.floor(best:getCount() * pct / 100)
	local creature = best:getCreature()
	local hex = battle:getAvailableHex(creature, side)
	if not hex:isValid() then return end
	server:addUnit(battle, { count = count, type = creature, side = side, position = hex, summoned = true })
	local key = creature:getJsonKey()
	local copy = battle:getUnitsIf(function(u)
		return u:isAlive() and u:getSide() == side and u:copy():isSummoned() and u:getCreature():getJsonKey() == key and not u:hasBonuses({ type = ILLUSION })
	end)[1]
	if copy == nil then return end
	mark(server, battle, copy, ILLUSION, copy:getAvailableHealth(), false)
	mark(server, battle, copy, DONE, 1, true)
	if server:describeChanges() then server:showBattleAnimation(battle, { { unit = copy } }, FX, "", 1.0, true) end
	server:refreshBattleUnits(battle)
	server:appendLog(battle, { append = { "core.bonus." .. ILLUSION .. ".description.1" }, replaceStrings = { creature:getNameTextID(count) }, replaceNumbers = { count } })
end

-- the illusion lost health (whoever hit it, however): it vanishes
function Script:check(server, battle, unit)
	if unit == nil or not unit:isAlive() then return end
	local full = unit:getBonusesValue({ type = ILLUSION })
	if full <= 0 or unit:getAvailableHealth() >= full then return end
	if server:describeChanges() then server:showBattleAnimation(battle, { { unit = unit } }, FX_OUT, "", 1.0, false) end      -- then leaves the field: not deferred
	server:appendLog(battle, { append = { "core.bonus." .. ILLUSION .. ".description.2" }, replaceStrings = { unit:getCreature():getNameTextID(unit:getCount()) }, replaceNumbers = { 0 } })
	server:removeUnit(battle, unit)
	server:refreshBattleUnits(battle)
end

-- No onAfterAttacked or onSpellHit: an illusion that is hit is not removed in the middle of attack resolution (the same pattern as the other mobile crash fixes);
-- the illusion that was hit takes part in this action, so onActionFinished removes it when the action ends
-- Script damage such as falling rocks, damage over time and splash (server:damageUnit) is not a battle action, so an illusion hit by it gets no onActionFinished.
-- The whole army carries this script, so some stack always gets here when an action ends; it checks every damaged illusion on the field while at it
function Script:onActionFinished(server, battle, unit, other)
	self:check(server, battle, unit)
	for _, u in ipairs(battle:getUnitsIf(function(u) return u:isAlive() and u:hasBonuses({ type = ILLUSION }) end)) do
		self:check(server, battle, u)
	end
end
function Script:onRoundStart(server, battle, unit, other) self:check(server, battle, unit) end

return Script
