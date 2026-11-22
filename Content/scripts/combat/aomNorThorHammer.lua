-- Thor's Hammer: Thor's creative specialty. At the start of each round the hammer strikes the enemy stack with the highest total health for 30 + hero level x 10 damage.
-- Counts as a level 2 Air spell (lightning): immunities by spell, school, negative effect and level are checked; Air and all-school damage reductions apply, magic resistance as usual.
-- Setup: COMBAT_EVENT_TRIGGER in the hero specialty (inherited by the whole army); the hero level comes from AOM_NOR_HERO_LEVEL (TIMES_HERO_LEVEL) in the same specialty.
-- Strikes once per side per round: as in the Favor script, the hidden SEEN / TICK counters tell whether this side was settled this round.
local Base = require("combat/combatScript")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local SEEN, TICK, LEVEL = "AOM_NOR_HAMMER_SEEN", "AOM_NOR_HAMMER_TICK", "AOM_NOR_HERO_LEVEL"

local function setValue(server, battle, unit, bonusType, value)
	local old = unit:getBonuses({ type = bonusType })
	if old:size() > 0 then server:removeUnitBonuses(battle, unit, old) end
	if value > 0 then
		server:addUnitBonus(battle, unit, { type = bonusType, sourceType = ENUM.BonusSource.other, val = value,
			valueType = ENUM.BonusValueType.baseNumber, duration = ENUM.BonusDuration.oneBattle, hidden = true }, false)
	end
end

local function immune(u)
	return u:hasBonuses({ type = "SPELL_IMMUNITY", subtype = "spell.lightningBolt" })
		or u:hasBonuses({ type = "SPELL_SCHOOL_IMMUNITY", subtype = "spellSchool.air" })
		or u:hasBonuses({ type = "SPELL_SCHOOL_IMMUNITY", subtype = "spellSchool.any" })
		or u:hasBonuses({ type = "NEGATIVE_EFFECTS_IMMUNITY", subtype = "spellSchool.air" })
		or u:hasBonuses({ type = "NEGATIVE_EFFECTS_IMMUNITY", subtype = "spellSchool.any" })
		or u:getBonusesValue({ type = "LEVEL_SPELL_IMMUNITY" }) >= 2
end

function Script:onBattleStart(server, battle, unit, other)
	setValue(server, battle, unit, SEEN, 1)
	self:strike(server, battle, unit, 1)      -- first round: the engine sends no round-start event for round 1 when the battle begins, so strike once here
end

function Script:onRoundStart(server, battle, unit, other)
	if not unit:isAlive() then return end
	local seen = unit:getBonusesValue({ type = SEEN }) + 1
	setValue(server, battle, unit, SEEN, seen)
	self:strike(server, battle, unit, seen)
end

function Script:strike(server, battle, unit, seen)
	if not unit:isAlive() or unit:isSummoned() then return end
	local side = unit:getSide()
	local own = battle:getUnitsIf(function(u) return u:isAlive() and u:getSide() == side and u:getBonusesValue({ type = SEEN }) > 0 end)
	local done = 0
	for _, u in ipairs(own) do done = math.max(done, u:getBonusesValue({ type = TICK })) end
	if done >= seen then return end
	for _, u in ipairs(own) do setValue(server, battle, u, TICK, seen) end

	local best, bestHp
	for _, e in ipairs(battle:getUnitsIf(function(u) return u:isAlive() and u:getSide() ~= side and not u:isGhost() and not u:isTurret() end)) do
		if not e:hasBonuses({ type = "SIEGE_WEAPON" }) then
			local hp = (e:getCount() - 1) * e:getMaxHealth() + e:getFirstHPleft()
			if not best or hp > bestHp then best, bestHp = e, hp end
		end
	end
	if not best then return end

	local level = math.max(1, unit:getBonusesValue({ type = LEVEL }))
	local dmg = (self.base or 30) + (self.perLevel or 10) * level
	local logKey = "core.bonus.AOM_NOR_HAMMER.description.1"
	if immune(best) then
		dmg = 0; logKey = "core.bonus.AOM_NOR_HAMMER.description.2"
	else
		local mr = best:getBonusesValue({ type = "MAGIC_RESISTANCE" })
		if mr > 0 and server:rngInt(0, 99) < mr then
			dmg = 0; logKey = "core.bonus.AOM_NOR_HAMMER.description.2"
		else
			local red = best:getBonusesValue({ type = "SPELL_DAMAGE_REDUCTION", subtype = "spellSchool.air" }) + best:getBonusesValue({ type = "SPELL_DAMAGE_REDUCTION", subtype = "spellSchool.any" })
			dmg = math.floor(dmg * math.max(0, 100 - math.min(100, red)) / 100)
		end
	end

	if server:describeChanges() then server:showBattleAnimation(battle, { { unit = best } }, "aom/nor/fx/hxHammer.json", "LIGHTBLT", 1.0, true) end
	if dmg > 0 then server:damageUnit(battle, best, dmg) end
	server:refreshBattleUnits(battle)
	server:appendLog(battle, { append = { logKey }, replaceStrings = { best:getCreature():getNameTextID(best:getCount()) }, replaceNumbers = { dmg } })
end

return Script
