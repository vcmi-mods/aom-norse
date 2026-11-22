-- Rune Forging (base skill of the Norse Rune Smith commander): at battle start and each round start one of our melee stacks gets a rune, +val Attack and Defense each, at most max runes per stack.
-- Choice: our living melee stacks (not shooters, war machines, Battering Rams, arrow towers or the commander itself); fewest runes first, ties go to the stack with the most total health.
-- The attack/defense bonuses and the visible marker AOM_NOR_RUNE use one stacking group each, so every new rune replaces the total and nothing piles up.
local Base = require("combat/combatScript")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local RUNE = "AOM_NOR_RUNE"
local FX = "aom/nor/fx/fxRuneCircle.json"

local function real(server)
	return not server.describeChanges or server:describeChanges()
end

local function eligible(u, side)
	return u:isAlive() and u:getSide() == side and not u:isTurret()
		and not u:isShooter() and not u:isCommander() and not u:hasBonuses({ type = "SIEGE_WEAPON" })
		and not u:getCreature():getJsonKey():match("aomNorRam$")
end

function Script:carve(server, battle, unit, quiet)
	if not unit:isAlive() then return end
	local max, val, side = self.max or 3, self.val or 1, unit:getSide()
	local best, bestRunes, bestHp
	for _, u in ipairs(battle:getUnitsIf(function(u) return eligible(u, side) end)) do
		local r = u:getBonusesValue({ type = RUNE })
		if r < max then
			local hp = (u:getCount() - 1) * u:getMaxHealth() + u:getFirstHPleft()
			if best == nil or r < bestRunes or (r == bestRunes and hp > bestHp) then best, bestRunes, bestHp = u, r, hp end
		end
	end
	if best == nil then return end
	local n = bestRunes + 1
	for _, s in ipairs({ "primarySkill.attack", "primarySkill.defence" }) do
		server:addUnitBonus(battle, best, { type = "PRIMARY_SKILL", subtype = s, val = n * val, valueType = ENUM.BonusValueType.baseNumber,
			duration = ENUM.BonusDuration.oneBattle, sourceType = ENUM.BonusSource.other, stacking = "aomNorRune" .. s, hidden = true }, false)
	end
	server:addUnitBonus(battle, best, { type = RUNE, val = n, valueType = ENUM.BonusValueType.baseNumber,
		duration = ENUM.BonusDuration.oneBattle, sourceType = ENUM.BonusSource.other, stacking = "aomNorRune" }, false)
	if real(server) then
		if not quiet then server:showBattleAnimation(battle, { { unit = best } }, FX, "BLESS", 1.0, true) end
		server:refreshBattleUnits(battle)
		server:appendLog(battle, {
			append = { "core.bonus." .. RUNE .. ".description.1" },
			replaceStrings = { best:getCreature():getNameTextID(best:getCount()) }, replaceNumbers = { n }
		})
	end
end

-- no rune animation at battle start: it collides with the full-screen animation of Odin's Wain and the client logs Unexpected animations state
function Script:onBattleStart(server, battle, unit, other) self:carve(server, battle, unit, true) end
function Script:onRoundStart(server, battle, unit, other) self:carve(server, battle, unit) end

return Script
