-- Freezing Strike (Primordial Frost Giant): once per battle, an attack (not retaliation) freezes the target, which loses its next turn.
-- nTurns is decreased at the end of this round, so turns+1 is applied: the target cannot act or retaliate for the rest of this round and the whole next one.
local Base = require("combat/combatScript")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local Sac = require("spells/aomNorSacCommon")
local USED, FROZEN = "AOM_NOR_FREEZE_USED", "AOM_NOR_FROZEN"

function Script:onAfterAttack(server, battle, unit, other, payload)
	if not payload or payload.isCounter or unit:hasBonuses({ type = USED }) then return end
	local t = payload.targets and payload.targets[1]
	local u = t and t.unit
	if not u or not u:isAlive() or u:hasBonuses({ type = "SPELL_SCHOOL_IMMUNITY", subtype = "spellSchool.water" }) then return end
	if u:isCommander() or u:hasBonuses({ type = "SIEGE_WEAPON" }) or Sac.isGuardian(u) then return end      -- commanders, war machines and capital guardians are not frozen
	server:addUnitBonus(battle, unit, { type = USED, val = 1, valueType = ENUM.BonusValueType.baseNumber,
		duration = ENUM.BonusDuration.oneBattle, sourceType = ENUM.BonusSource.other, hidden = true }, false)
	server:addUnitBonus(battle, u, { type = "NOT_ACTIVE", val = 0, valueType = ENUM.BonusValueType.baseNumber,
		duration = ENUM.BonusDuration.nTurns, turns = (self.turns or 1) + 1, sourceType = ENUM.BonusSource.other, hidden = true }, false)
	server:addUnitBonus(battle, u, { type = FROZEN, val = self.turns or 1, valueType = ENUM.BonusValueType.baseNumber,
		duration = ENUM.BonusDuration.nTurns, turns = (self.turns or 1) + 1, sourceType = ENUM.BonusSource.other }, false)
	if server:describeChanges() then server:showBattleAnimation(battle, { { unit = u } }, "aom/nor/fx/spFrost.json", "", 1.0, true) end      -- ice block (same clip as Frost Prison)
	server:refreshBattleUnits(battle)
	server:appendLog(battle, { append = { "core.bonus." .. FROZEN .. ".description.1" },
		replaceStrings = { u:getCreature():getNameTextID(u:getCount()) }, replaceNumbers = { self.turns or 1 } })
end

return Script
