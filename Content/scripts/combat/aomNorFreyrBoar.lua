-- Golden Boar: Freyr's creative specialty. At battle start Gullinbursti is summoned on our side to fight for us, count 1 + hero level / 8 (rounded down);
-- it is a summon: it leaves after the battle, never goes to towns and cannot be recruited.
-- Setup: COMBAT_EVENT_TRIGGER in the hero specialty (inherited by the whole army); the hero level comes from AOM_NOR_HERO_LEVEL (TIMES_HERO_LEVEL) in the same specialty.
local Base = require("combat/combatScript")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local DONE, LEVEL, BOAR = "AOM_NOR_BOAR_DONE", "AOM_NOR_HERO_LEVEL", "aom-norse:aomNorGullinbursti"

function Script:onBattleStart(server, battle, unit, other)
	if not unit:isAlive() or unit:isSummoned() then return end
	local side = unit:getSide()
	local own = battle:getUnitsIf(function(u) return u:getSide() == side end)
	for _, u in ipairs(own) do
		if u:hasBonuses({ type = DONE }) then return end
	end
	for _, u in ipairs(own) do
		server:addUnitBonus(battle, u, { type = DONE, sourceType = ENUM.BonusSource.other, val = 1, valueType = ENUM.BonusValueType.baseNumber,
			duration = ENUM.BonusDuration.oneBattle, hidden = true }, false)
	end
	local creature = LIBRARY:getCreatureByName(BOAR)
	if creature == nil then return end
	local level = math.max(1, unit:getBonusesValue({ type = LEVEL }))
	local count = 1 + math.floor(level / (self.per or 8))
	local hex = battle:getAvailableHex(creature, side)
	if not hex:isValid() then return end
	server:addUnit(battle, { count = count, type = creature, side = side, position = hex, summoned = true })
	local boar = battle:getUnitsIf(function(u) return u:isAlive() and u:getSide() == side and u:isSummoned() and u:getCreature():getJsonKey() == creature:getJsonKey() end)[1]
	if boar ~= nil and server:describeChanges() then server:showBattleAnimation(battle, { { unit = boar } }, "aom/nor/fx/apBoar.json", "BLESS", 1.0, true) end
	server:refreshBattleUnits(battle)
	server:appendLog(battle, { append = { "core.bonus.AOM_NOR_BOAR_DONE.description.1" }, replaceStrings = { creature:getNameTextID(count) }, replaceNumbers = { count } })
end

return Script
