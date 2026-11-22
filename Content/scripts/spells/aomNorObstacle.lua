-- Obstacles of Norse god powers (the spring of Healing Spring, the hill fort of Spectral Fortress): core obstacle plus two things
--   patron affinity: if the caster's major god is in "gods", it stays "extraTurns" (default 1) rounds longer (matching the effect in aomNorSite)
--   "ownHalf": true can only be placed on our half of the battlefield
local Base = require("spells/obstacle")
local Sac = require("spells/aomNorSacCommon")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

function Script:applicableTarget(mechanics, problem, target)
	for _, dest in ipairs(target) do
		if not dest.hex or not dest.hex:isValid() then
			problem:addStandard(mechanics, ENUM.SpellCastProblem.noAppropriateTarget)
			return false
		end
		if self.ownHalf then
			local x, attacker = dest.hex:getX(), mechanics:getCasterSide() == ENUM.BattleSide.attacker
			if (attacker and x > 8) or (not attacker and x < 8) then
				problem:addStandard(mechanics, ENUM.SpellCastProblem.noAppropriateTarget)
				return false
			end
		end
	end
	return Base.applicableTarget(self, mechanics, problem, target)
end

function Script:apply(mechanics, server, target)
	local plain = self.turnsRemaining
	if plain and plain > 0 and Sac.favoured(self, mechanics) then self.turnsRemaining = plain + (self.extraTurns or 1) end
	Base.apply(self, mechanics, server, target)
	self.turnsRemaining = plain
end

return Script
