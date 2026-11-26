-- Status effect of Norse god powers: core timed plus three things
--   Soul Offering: bonus values are scaled by the bonus ("noScale": true ones are not, e.g. integer switches like freezing or speed)
--   patron affinity: if the caster's major god is in "gods", it lasts "extraTurns" (default 1) rounds longer
--   "mass": "own" / "enemy" affects one whole side (regardless of the hex clicked), "filter" picks stacks (aomNorSacCommon.passes: living, lines = Berserker and Axeman lines, notFlying)
--   "trialRatio": in AI evaluation (describeChanges false) no bonus is applied; instead each hit enemy ground melee stack reports remaining health x trialRatio as equivalent damage.
--     For slows: BattleAI re-evaluates the whole turn order as soon as speed changes and scores that far above any damage, so a book with it would cast only that every round (the slows of Fimbulwinter and Tempest).
local Base = require("spells/timed")
local Sac = require("spells/aomNorSacCommon")
local P = require("lib/kadAiProxy")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

function Script:convertBonuses(mechanics)
	local out = Base.convertBonuses(self, mechanics)
	local boost = Sac.boost(mechanics)
	local extra = Sac.favoured(self, mechanics) and (self.extraTurns or 1) or 0
	for _, nb in pairs(out) do
		if boost > 0 and not self.noScale and nb.val and nb.val ~= 0 then
			local v = nb.val * (100 + boost) / 100
			nb.val = v >= 0 and math.floor(v + 0.5) or -math.floor(-v + 0.5)
		end
		if extra > 0 and nb.turns and nb.turns > 0 then nb.turns = nb.turns + extra end
	end
	return out
end

function Script:apply(mechanics, server, target)
	if not self.trialRatio or not P.trial(server) then return Base.apply(self, mechanics, server, target) end
	local battle, side = mechanics:getBattle(), mechanics:getCasterSide()
	for _, dest in ipairs(target) do
		local u = dest.unit
		if u and u:isAlive() and u:getSide() ~= side and not u:isShooter() and not u:hasBonuses({ type = "FLYING" }) then
			P.damage(server, battle, u, u:getAvailableHealth() * self.trialRatio)
		end
	end
end

function Script:isValidTarget(mechanics, unit)
	if self.filter and not Sac.passes(self.filter, unit) then return false end
	return Base.isValidTarget(self, mechanics, unit)
end

function Script:transformTarget(mechanics, aimPoint, spellTarget)
	if self.mass then return Sac.massTarget(self, mechanics, self.mass) end
	return Base.transformTarget(self, mechanics, aimPoint, spellTarget)
end

function Script:applicableGeneral(mechanics, problem)
	if self.mass then
		if #Sac.massTarget(self, mechanics, self.mass) > 0 then return true end
		problem:addStandard(mechanics, ENUM.SpellCastProblem.noAppropriateTarget)
		return false
	end
	return Base.applicableGeneral(self, mechanics, problem)
end
function Script:applicableTarget(mechanics, problem, target)
	if self.mass then return true end
	return Base.applicableTarget(self, mechanics, problem, target)
end
function Script:adjustAffectedHexes(mechanics, hexes, spellTarget)
	if self.mass then return hexes end
	return Base.adjustAffectedHexes(self, mechanics, hexes, spellTarget)
end

-- the engine calls this function when choosing targets; the unitEffect base class does not have it

--- Cursor and status bar text while choosing a target: return nil to use the engine default ("Cast X on Y" / "Cast X", with damage and healing estimates added automatically).
--- Every spell effect script must define this function.
function Script:describeTargetStep(mechanics, partialTarget, hoveredHex)
	return nil
end

return Script
