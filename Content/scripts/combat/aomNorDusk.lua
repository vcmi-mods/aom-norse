-- Twilight Valor (the Norse Rune Smith commander's skill after spell enchantment): after one of our stacks is wiped out, at the start of the next round the other stacks get +val Morale and +attack Attack for turns rounds.
-- The commander only receives round-start events while alive, so at round start it counts our stacks wiped out so far (not summons, clones or war machines) and triggers when the count went up, at most once per round.
-- The count already seen is stored on the commander (AOM_NOR_DUSK_SEEN); the bonuses share one stacking group, so a new trigger only refreshes the duration and does not stack.
local Base = require("combat/combatScript")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local DUSK, SEEN = "AOM_NOR_DUSK", "AOM_NOR_DUSK_SEEN"

local function real(server)
	return not server.describeChanges or server:describeChanges()
end

local function fallen(battle, side)
	return battle:getUnitsIf(function(u)
		return u:getSide() == side and u:isDead() and not u:isTurret() and not u:copy():isSummoned() and not u:isClone()
			and not u:hasBonuses({ type = "SIEGE_WEAPON" })
	end)
end

function Script:check(server, battle, unit, fire)
	if not unit:isAlive() then return end
	local side = unit:getSide()
	local dead = fallen(battle, side)
	local seen = unit:getBonusesValue({ type = SEEN })
	if #dead <= seen then return end
	server:addUnitBonus(battle, unit, { type = SEEN, val = #dead, valueType = ENUM.BonusValueType.baseNumber, duration = ENUM.BonusDuration.oneBattle,
		sourceType = ENUM.BonusSource.other, stacking = "aomNorDuskSeen", hidden = true }, false)
	if not fire then return end
	local morale, attack, turns = self.val or 1, self.attack or 2, self.turns or 2
	local targets = {}
	for _, u in ipairs(battle:getUnitsIf(function(u) return u:isAlive() and u:getSide() == side and not u:hasBonuses({ type = "SIEGE_WEAPON" }) end)) do
		server:addUnitBonus(battle, u, { type = "MORALE", val = morale, duration = ENUM.BonusDuration.nTurns, turns = turns,
			sourceType = ENUM.BonusSource.other, stacking = "aomNorDuskMorale", hidden = true }, false)
		server:addUnitBonus(battle, u, { type = "PRIMARY_SKILL", subtype = "primarySkill.attack", val = attack, valueType = ENUM.BonusValueType.baseNumber,
			duration = ENUM.BonusDuration.nTurns, turns = turns, sourceType = ENUM.BonusSource.other, stacking = "aomNorDuskAttack", hidden = true }, false)
		server:addUnitBonus(battle, u, { type = DUSK, val = attack, valueType = ENUM.BonusValueType.baseNumber, duration = ENUM.BonusDuration.nTurns, turns = turns,
			sourceType = ENUM.BonusSource.other, stacking = "aomNorDusk" }, false)
		targets[#targets + 1] = { unit = u }
	end
	if real(server) and #targets > 0 then
		server:showBattleAnimation(battle, targets, "aom/nor/fx/hxRage.json", "PRAYER", 1.0, true)
		server:refreshBattleUnits(battle)
		local last = dead[#dead]
		server:appendLog(battle, {
			append = { "core.bonus." .. DUSK .. ".description.1" },
			replaceStrings = { last:getCreature():getNameTextID(2) }, replaceNumbers = { attack }
		})
	end
end

-- At battle start only record the existing count (no losses before battle, e.g. in sieges); triggers from round 2 on
function Script:onBattleStart(server, battle, unit, other) self:check(server, battle, unit, false) end
function Script:onRoundStart(server, battle, unit, other) self:check(server, battle, unit, true) end

return Script
