-- Summon effect of Norse god powers: core summon plus four things
--   Soul Offering: the summoned amount is scaled by the bonus
--   "pool": ["creature", ...] each cast summons one of them at random (Great Hunt); otherwise "id" is summoned
--   "once": true summoned only once per battle (Nidhogg): cannot be cast again once we have summoned this creature (alive or dead)
--   "minCount": n summon at least n (Nidhogg: at least one, more with higher power)
--   "animation": animation  an entry animation played on the summoned stack (the original god power entry effect)
local Base = require("spells/summon")
local Sac = require("spells/aomNorSacCommon")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

function Script:summonedEffectValue(mechanics)
	return Sac.scale(mechanics, Base.summonedEffectValue(self, mechanics))
end

function Script:summonedCreatureAmount(mechanics)
	return math.max(self.minCount or 0, Base.summonedCreatureAmount(self, mechanics))
end

local function already(self, mechanics)
	local battle, side, key = mechanics:getBattle(), mechanics:getCasterSide(), LIBRARY:getCreatureByName(self.id):getJsonKey()
	return #battle:getUnitsIf(function(u) return u:getSide() == side and u:getCreature():getJsonKey() == key end) > 0
end

function Script:applicableGeneral(mechanics, problem)
	if self.once and already(self, mechanics) then
		problem:addStandard(mechanics, ENUM.SpellCastProblem.noAppropriateTarget)
		return false
	end
	return Base.applicableGeneral(self, mechanics, problem)
end

local function appear(self, mechanics, server, id)
	if not self.animation or not server:describeChanges() then return end
	local battle, side = mechanics:getBattle(), mechanics:getCasterSide()
	local key = LIBRARY:getCreatureByName(id):getJsonKey()
	local list = {}
	for _, u in ipairs(battle:getUnitsIf(function(u) return u:isAlive() and u:getSide() == side and u:getCreature():getJsonKey() == key end)) do
		table.insert(list, { unit = u })
	end
	if #list > 0 then server:showBattleAnimation(battle, list, self.animation, "", 1.0, false) end
end

function Script:apply(mechanics, server, target)
	if self.pool and #self.pool > 0 then
		local default = self.id
		self.id = self.pool[server:rngInt(1, #self.pool)]
		if self.id ~= default then
			-- the hex the engine picked for the default creature may not fit another one (one-hex vs two-hex), so search again
			target = Base.transformTarget(self, mechanics, {}, {})
		end
		Base.apply(self, mechanics, server, target)
		appear(self, mechanics, server, self.id)
		self.id = default
		return
	end
	Base.apply(self, mechanics, server, target)
	appear(self, mechanics, server, self.id)
end

--- Cursor and status bar text while choosing a target: return nil to use the engine default ("Cast X on Y" / "Cast X", with damage and healing estimates added automatically).
--- Every spell effect script must define this function.
function Script:describeTargetStep(mechanics, partialTarget, hoveredHex)
	return nil
end

return Script
