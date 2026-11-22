-- Capsize (Storm Kraken): +val% damage when attacking two-hex enemies (the kraken overturns great ships and beasts). Retaliation counts too.
local Base = require("combat/combatScript")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script
local GROUP = "aomNorCapsize"   -- remove exactly this bonus only (not the damage bonuses of Svinfylking or Ragnarok)
local P = require("lib/kadAiProxy")

local function isBig(u)
	local h = u:getHexes()
	if type(h) == "table" then return #h > 1 end
	return h and h.size and h:size() > 1
end

function Script:onBeforeAttack(server, battle, unit, other)
	if not unit:isAlive() or not other then return end
	local old = unit:getBonuses({ type = "PERCENTAGE_DAMAGE_BOOST" }):filter(function(b) return b:getStacking() == GROUP end)
	if old:size() > 0 then P.removeExact(server, battle, unit, old) end
	if not isBig(other) then return end
	server:addUnitBonus(battle, unit, { type = "PERCENTAGE_DAMAGE_BOOST", subtype = "damageTypeMelee", val = self.val or 50,
		valueType = ENUM.BonusValueType.additiveValue, duration = ENUM.BonusDuration.oneBattle, sourceType = ENUM.BonusSource.other, stacking = GROUP, hidden = true }, false)
end

return Script
