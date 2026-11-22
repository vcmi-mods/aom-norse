-- Breath after-damage (the Flame Fafnir's burning, the Ginnungagap Titan's frost-and-fire): after each attack every target hit takes elemental damage equal to val% of that damage.
-- addInfo.schools = list of elements ("fire", "water"), each counted once; a target immune to that school skips that part.
local Base = require("combat/combatScript")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local function immune(u, school)
	return u:hasBonuses({ type = "SPELL_SCHOOL_IMMUNITY", subtype = "spellSchool." .. school })
		or u:hasBonuses({ type = "SPELL_SCHOOL_IMMUNITY", subtype = "spellSchool.any" })
end

function Script:onAfterAttack(server, battle, unit, other, payload)
	if not payload or not payload.targets then return end
	local schools = self.schools or { "fire" }
	local total = 0
	for _, t in ipairs(payload.targets) do
		local u = t.unit
		if u and u:isAlive() and (t.damage or 0) > 0 then
			for _, s in ipairs(schools) do
				if not u:isAlive() then break end
				if not immune(u, s) then
					local hp = math.min(math.floor(t.damage * (self.val or 15) / 100), u:getAvailableHealth())
					if hp > 0 then server:damageUnit(battle, u, hp) total = total + hp end
				end
			end
		end
	end
	if total > 0 then
		server:appendLog(battle, { append = { "core.bonus.AOM_NOR_BURN.description.1" },
			replaceStrings = { unit:getCreature():getNameTextID(unit:getCount()) }, replaceNumbers = { total } })
	end
end

return Script
