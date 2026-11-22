-- Damage over time of Norse god powers: battle script attached by the aomNorDot spell effect. Takes val damage at the start of each round (addInfo.school is the element; units immune to that school are unaffected).
local Base = require("combat/combatScript")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local function immune(u, school)
	return u:hasBonuses({ type = "SPELL_SCHOOL_IMMUNITY", subtype = "spellSchool." .. school })
		or u:hasBonuses({ type = "SPELL_SCHOOL_IMMUNITY", subtype = "spellSchool.any" })
end

function Script:onRoundStart(server, battle, unit, other)
	if not unit:isAlive() then return end
	local school = self.school or "fire"
	if immune(unit, school) then return end
	local hp = math.min(self.val or 0, unit:getAvailableHealth())
	if hp <= 0 then return end
	local name = unit:getCreature():getNameTextID(unit:getCount())
	local _, killed = server:damageUnit(battle, unit, hp)
	if not server.describeChanges or server:describeChanges() then
		server:appendLog(battle, { append = { "core.bonus.AOM_NOR_DOT.description." .. (school == "fire" and "1" or "2") }, replaceStrings = { name }, replaceNumbers = { hp, killed or 0 } })
	end
end

return Script
