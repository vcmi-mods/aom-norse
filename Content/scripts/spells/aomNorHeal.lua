-- Healing effect of Norse god powers: like core heal, the amount scaled by the Soul Offering bonus; "filter": "siege" repairs only our war machines (Dwarven Armor), "mass": "own" affects our whole army.
local Base = require("spells/heal")
local Sac = require("spells/aomNorSacCommon")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

function Script:getHealAmount(mechanics, unit, server)
	return Sac.scale(mechanics, Base.getHealAmount(self, mechanics, unit, server))
end

function Script:isValidTarget(mechanics, unit)
	if self.filter == "siege" then return unit:isAlive() and Sac.passes("siege", unit) end
	if self.filter and not Sac.passes(self.filter, unit) then return false end
	return Base.isValidTarget(self, mechanics, unit)
end

function Script:isReceptive(mechanics, unit)
	if self.filter == "siege" then return true end
	return Base.isReceptive(self, mechanics, unit)
end

function Script:transformTarget(mechanics, aimPoint, spellTarget)
	if self.mass then return Sac.massTarget(self, mechanics, self.mass) end
	return Base.transformTarget(self, mechanics, aimPoint, spellTarget)
end

function Script:applicableGeneral(mechanics, problem) return true end
function Script:applicableTarget(mechanics, problem, target) return true end

-- the engine calls this function when choosing targets; the unitEffect base class does not have it
function Script:describeTargetStep(mechanics, aimPoint, spellTarget) return nil end

return Script
