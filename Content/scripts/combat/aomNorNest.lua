-- Return to the Nest (the Norse Rune Smith commander's summon, the ravens): after the ravens are wiped out they fly back at the start of the next round with the count summoned at battle start, val times per battle;
-- plus more times if the skill was enchanted at summoning (ravens with CK_ENHANCED). Dead stacks get no round-start events, so the commander checks every round start.
-- The engine removes dead summons from the battlefield at once (ghost), so looking for our dead ravens found nothing and the ravens never came back.
-- Instead the commander records every round how many ravens are alive (AOM_NOR_NEST_N) and whether they are enchanted (AOM_NOR_NEST_E); if at round start we have no ravens
-- but a count was recorded, that many are summoned back. Uses spent are stored on the commander (AOM_NOR_NEST).
local Base = require("combat/combatScript")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local NEST, NEST_N, NEST_E, ENHANCED = "AOM_NOR_NEST", "AOM_NOR_NEST_N", "AOM_NOR_NEST_E", "commander-kits:CK_ENHANCED"
local FX = "ckfx/ckfx_norse"

local function real(server)
	return not server.describeChanges or server:describeChanges()
end

local function record(server, battle, unit, bonusType, value)
	local old = unit:getBonuses({ type = bonusType })
	if old:size() > 0 then server:removeUnitBonuses(battle, unit, old) end
	if value > 0 then
		server:addUnitBonus(battle, unit, { type = bonusType, val = value, valueType = ENUM.BonusValueType.baseNumber, duration = ENUM.BonusDuration.oneBattle,
			sourceType = ENUM.BonusSource.other, hidden = true }, false)
	end
end

local function enhanced(u)
	local ok, plus = pcall(function() return u:hasBonuses({ type = ENHANCED }) end)
	return ok and plus
end

function Script:onRoundStart(server, battle, unit, other)
	if not unit:isAlive() then return end
	local creature = LIBRARY:getCreatureByName(self.creature or "commander-kits.norse:ck_duya")
	if creature == nil then return end
	local side, key = unit:getSide(), creature:getJsonKey()
	local alive = battle:getUnitsIf(function(u)
		return u:isAlive() and u:getSide() == side and u:getCreature():getJsonKey() == key
	end)
	if #alive > 0 then
		local n, plus = 0, false
		for _, u in ipairs(alive) do
			n = math.max(n, u:getBaseAmount())
			plus = plus or enhanced(u)
		end
		record(server, battle, unit, NEST_N, n)
		record(server, battle, unit, NEST_E, plus and 1 or 0)
		return
	end
	local count = unit:getBonusesValue({ type = NEST_N })
	if count <= 0 then return end
	local plus = unit:getBonusesValue({ type = NEST_E }) > 0
	local used = unit:getBonusesValue({ type = NEST })
	local cap = (self.val or 2) + (plus and (self.plus or 1) or 0)
	if used >= cap then return end
	local hex = battle:getAvailableHex(creature, side)
	if not hex:isValid() then return end
	local new = server:addUnit(battle, { count = count, type = creature, side = side, position = hex, summoned = true })
	used = used + 1
	record(server, battle, unit, NEST, used)
	if new and plus then
		server:addUnitBonus(battle, new, { type = ENHANCED, val = 1, duration = ENUM.BonusDuration.oneBattle, sourceType = ENUM.BonusSource.other, hidden = true }, false)
	end
	if real(server) then
		if new then server:showBattleAnimation(battle, { { unit = new } }, FX, "PRAYER", 1.0, true) end
		server:refreshBattleUnits(battle)
		server:appendLog(battle, {
			append = { "core.bonus." .. NEST .. ".description.1" },
			replaceStrings = { creature:getNameTextID(count) }, replaceNumbers = { count }
		})
	end
end

return Script
