-- Damage over time of Norse god powers (the fire of Forest Fire, the ice of Frost and Fimbulwinter): attaches the battle script combat/aomNorDot to the target,
-- which then takes damage at the start of each round, for as many rounds as the spell lasts ("turns" if fixed).
-- Damage per round = the spell's damage to this stack (power x spell power + levelPower, with specialty, affinity and resistance) x "factor" x (1 + Soul Offering bonus).
-- Config: {"type": "aomNorDot", "factor": 0.5, "turns": 2, "school": "fire", "mass": "enemy" or absent (spell area), "filter": ...}
local Base = require("spells/unitEffect")
local Sac = require("spells/aomNorSacCommon")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

function Script:isValidTarget(mechanics, unit)
	if self.filter and not Sac.passes(self.filter, unit) then return false end
	return Base.isValidTarget(self, mechanics, unit)
end

function Script:transformTarget(mechanics, aimPoint, spellTarget)
	if self.mass then return Sac.massTarget(self, mechanics, self.mass) end
	return Base.transformTarget(self, mechanics, aimPoint, spellTarget)
end

function Script:applicableGeneral(mechanics, problem) return true end
function Script:applicableTarget(mechanics, problem, target) return true end

function Script:apply(mechanics, server, target)
	local battle = mechanics:getBattle()
	local spellKey = mechanics:getSpell():getJsonKey()
	local turns = (self.turns or mechanics:getEffectDuration()) + (Sac.favoured(self, mechanics) and 1 or 0)
	for _, dest in ipairs(target) do
		local unit = dest.unit
		-- per-round damage computed for this stack (with specialty, affinity and resistance, like the spell's own damage)
		local per = unit and Sac.scale(mechanics, math.floor(mechanics:adjustEffectValue(unit) * (self.factor or 0.5))) or 0
		if unit and unit:isAlive() and per > 0 then
			-- the same spell lands on this stack again: remove the old one first (the engine updates a bonus of the same source in place without changing its value), keep the larger
			local old = unit:getBonuses({ type = "COMBAT_EVENT_TRIGGER" }):filter(function(b) return b:getStacking() == spellKey end)
			for i = 1, old:size() do per = math.max(per, old:getBonus(i):getVal()) end
			if old:size() > 0 then server:removeUnitBonuses(battle, unit, old) end
			server:addUnitBonus(battle, unit, {
				type = "COMBAT_EVENT_TRIGGER", subtype = "aomNorDot", val = per,
				duration = ENUM.BonusDuration.nTurns, turns = turns,
				sourceType = ENUM.BonusSource.spellEffect, sourceID = spellKey, sourceSecondaryID = mechanics:getEffectLevel(), stacking = spellKey,
				addInfo = { school = self.school or "fire" }
			}, false)
		end
	end
end

-- the engine calls this function when choosing targets; the unitEffect base class does not have it

--- Cursor and status bar text while choosing a target: return nil to use the engine default ("Cast X on Y" / "Cast X", with damage and healing estimates added automatically).
--- Every spell effect script must define this function.
function Script:describeTargetStep(mechanics, partialTarget, hoveredHex)
	return nil
end

return Script
