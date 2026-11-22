-- Berserk Rage (Bear-Skin Berserker): while the stack's remaining health is below half of its battle-start health (self.threshold percent), Attack +val%; removed once healed above it.
-- The state is the visible bonus AOM_NOR_RAGE (icon, description) plus an attack percentage bonus from the same source; both are added and removed together.
local Base = require("combat/combatScript")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local RAGE = "AOM_NOR_RAGE"
local GROUP = "aomNorRage"      -- the attack bonus has its own stacking group and only this bonus is removed (the engine does not compare stacking groups when removing, which would also strip rune, Twilight Valor and Favor attack bonuses)
local P = require("lib/kadAiProxy")

local function showAnim(server, ...)
	if server.describeChanges and not server:describeChanges() then return end
	server:showBattleAnimation(...)
end

local function healthLeft(unit)
	local per = unit:getMaxHealth()
	local now = (unit:getCount() - 1) * per + unit:getFirstHPleft()
	local full = math.max(1, unit:getBaseAmount()) * per
	return now * 100 / full
end

function Script:update(server, battle, unit)
	if not unit:isAlive() then return end
	local raging = unit:hasBonuses({ type = RAGE })
	local want = healthLeft(unit) < (self.threshold or 50)
	if want == raging then return end
	if raging then
		P.removeExact(server, battle, unit, unit:getBonuses({ type = RAGE }))
		local mine = unit:getBonuses({ type = "PRIMARY_SKILL", subtype = "primarySkill.attack" }):filter(function(b) return b:getStacking() == GROUP end)
		if mine:size() > 0 then P.removeExact(server, battle, unit, mine) end
		return
	end
	local val = self.val or 50
	server:addUnitBonus(battle, unit, { type = "PRIMARY_SKILL", subtype = "primarySkill.attack", val = val,
		valueType = ENUM.BonusValueType.percentToBase, duration = ENUM.BonusDuration.oneBattle, sourceType = ENUM.BonusSource.other, stacking = GROUP, hidden = true }, false)
	server:addUnitBonus(battle, unit, { type = RAGE, val = val, valueType = ENUM.BonusValueType.baseNumber,
		duration = ENUM.BonusDuration.oneBattle, sourceType = ENUM.BonusSource.other }, false)
	showAnim(server, battle, { { unit = unit } }, "aom/nor/fx/hxRage.json", "PRAYER", 1.0, true) server:refreshBattleUnits(battle)
	server:appendLog(battle, {
		append         = { "core.bonus." .. RAGE .. ".description.1" },
		replaceStrings = { unit:getCreature():getNameTextID(unit:getCount()) },
		replaceNumbers = { val }
	})
end

function Script:onBattleStart(server, battle, unit, other) self:update(server, battle, unit) end
function Script:onRoundStart(server, battle, unit, other) self:update(server, battle, unit) end
function Script:onAfterAttacked(server, battle, unit, other) self:update(server, battle, unit) end
function Script:onSpellHit(server, battle, unit, other) self:update(server, battle, unit) end
function Script:onActionFinished(server, battle, unit, other) self:update(server, battle, unit) end

return Script
