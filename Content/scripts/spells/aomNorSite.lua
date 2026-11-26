-- The "effect" part of Norse god powers placed on the ground (Healing Spring, Spectral Fortress): the obstacle (look, blocking) is a separate core obstacle effect; here the place and values are recorded.
-- Every unit of the casting side gets a hidden battle script combat/aomNorSite (same stacking per cast), settled once per round start by the stack with the lowest id:
--   "kind": "spring" our stacks within "radius" hexes of the spring each regain val health; "fort" the hill fort shoots one arrow at the nearest enemy for val damage.
-- val = spell value (power x spell power + levelPower, with patron affinity) x "factor" x (1 + Soul Offering bonus); lasts "turns" rounds (one more with patron affinity, like the obstacle).
local Base = require("spells/spellEffect")
local Sac = require("spells/aomNorSacCommon")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

function Script:applicableGeneral(mechanics, problem) return true end
function Script:applicableTarget(mechanics, problem, target) return true end

function Script:apply(mechanics, server, target)
	local hex = nil
	for _, dest in ipairs(target) do
		if dest.hex and dest.hex:isValid() then hex = dest.hex break end
	end
	if hex == nil then return end
	local battle, side = mechanics:getBattle(), mechanics:getCasterSide()
	local val = Sac.scale(mechanics, math.floor(mechanics:applySpecificSpellBonus(mechanics:getEffectValue()) * (self.factor or 1)))
	if val <= 0 then return end
	local turns = (self.turns or mechanics:getEffectDuration()) + (Sac.favoured(self, mechanics) and (self.extraTurns or 1) or 0)
	-- AI evaluation (describeChanges false): the AI compares values before and after casting on a hypothetical battlefield; just adding a script changes no value, so it would never cast.
	-- So the rough worth is reported as an equivalent change in evaluation (never kept on the real battlefield): the spring heals each wounded own stack within two hexes once x half the rounds,
	-- the hill fort shoots the nearest enemy half the rounds times. Real casts only add the script as usual.
	if not server:describeChanges() then
		local times = math.max(1, math.floor(turns / 2))
		if self.kind == "spring" then
			for _, u in ipairs(battle:getUnitsIf(function(u) return u:isAlive() and u:getSide() == side and not u:isTurret() end)) do
				local p = u:getPosition()
				if math.abs(p:getX() - hex:getX()) <= 3 and math.abs(p:getY() - hex:getY()) <= 2 then server:healUnit(battle, u, val * times, ENUM.HealLevel.heal, ENUM.HealPower.permanent) end
			end
		elseif self.kind == "fort" then
			local best, bd = nil, 999
			for _, u in ipairs(battle:getUnitsIf(function(u) return u:isAlive() and u:getSide() ~= side and not u:isTurret() end)) do
				local p = u:getPosition()
				local d = math.abs(p:getX() - hex:getX()) + math.abs(p:getY() - hex:getY())
				if d < bd then best, bd = u, d end
			end
			if best then server:damageUnit(battle, best, math.min(val * times, best:getAvailableHealth())) end
		end
		return
	end
	local tag = mechanics:getSpell():getJsonKey() .. "@" .. hex:getX() .. "," .. hex:getY()
	for _, u in ipairs(battle:getUnitsIf(function(u) return u:isAlive() and u:getSide() == side and not u:isTurret() end)) do
		server:addUnitBonus(battle, u, {
			type = "COMBAT_EVENT_TRIGGER", subtype = "aomNorSite", val = val,
			duration = ENUM.BonusDuration.nTurns, turns = turns, hidden = true,
			sourceType = ENUM.BonusSource.spellEffect, sourceID = mechanics:getSpell():getJsonKey(), sourceSecondaryID = mechanics:getEffectLevel(), stacking = tag,
			addInfo = { kind = self.kind, x = hex:getX(), y = hex:getY(), radius = self.radius or 2, animation = self.animation or "" }
		}, true)      -- cumulative: when the same spell is cast in a second place the engine would overwrite the first one's bonus in place (place and values unchanged), so it must stack as two
	end
end

--- Cursor and status bar text while choosing a target: return nil to use the engine default ("Cast X on Y" / "Cast X", with damage and healing estimates added automatically).
--- Every spell effect script must define this function.
function Script:describeTargetStep(mechanics, partialTarget, hoveredHex)
	return nil
end

return Script
