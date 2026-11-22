-- Damage effect of Norse god powers: like core damage, scaled by the Soul Offering bonus.
-- Extra config "filter" (see aomNorSacCommon.passes, e.g. "notFlying": the hail does not hit flyers) and "mass" ("enemy" = all enemies, regardless of the hex clicked).
local Base = require("spells/damage")
local Sac = require("spells/aomNorSacCommon")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

function Script:damageForTarget(targetIndex, mechanics, unit)
	return Sac.scale(mechanics, Base.damageForTarget(self, targetIndex, mechanics, unit))
end

function Script:isValidTarget(mechanics, unit)
	if self.filter and not Sac.passes(self.filter, unit) then return false end
	return Base.isValidTarget(self, mechanics, unit)
end

function Script:transformTarget(mechanics, aimPoint, spellTarget)
	if self.mass then return Sac.massTarget(self, mechanics, self.mass) end
	return Base.transformTarget(self, mechanics, aimPoint, spellTarget)
end

-- the engine calls this function when choosing targets; the unitEffect base class does not have it
function Script:describeTargetStep(mechanics, aimPoint, spellTarget) return nil end

return Script
