-- Dash of Fenrir's Inferno: Fenrir runs from our side along the row of the target hex to the target hex, biting the enemies on the way (damage as core damage, with the Soul Offering bonus).
-- The explosion and lingering fire at the end are the spell's two other effects (aomNorDamage radius 0-1, aomNorDotEffect).
local Base = require("spells/aomNorDamage")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

function Script:transformTarget(mechanics, aimPoint, spellTarget)
	local aim = nil
	for _, dest in ipairs(aimPoint or {}) do
		if dest.hex and dest.hex:isValid() then aim = dest.hex break end
	end
	if aim == nil then return {} end
	local battle, side, seen, out = mechanics:getBattle(), mechanics:getCasterSide(), {}, {}
	local ax, ay = aim:getX(), aim:getY()
	local arr = battle:getAllPossibleHexes()
	for i = 1, arr:size() do
		local h = arr:at(i)
		local onPath = h:getY() == ay and ((side == ENUM.BattleSide.attacker and h:getX() <= ax) or (side ~= ENUM.BattleSide.attacker and h:getX() >= ax))
		if onPath then
			local u = battle:getUnitByPos(h, true)
			if u and u:getSide() ~= side and not seen[u:unitID()] and not u:isTurret() and self:isValidTarget(mechanics, u) and self:isReceptive(mechanics, u) then
				seen[u:unitID()] = true
				out[#out + 1] = { unit = u, hex = h }
			end
		end
	end
	return out
end

function Script:applicableGeneral(mechanics, problem) return true end
function Script:applicableTarget(mechanics, problem, target) return true end

-- the engine calls this function when choosing targets; the unitEffect base class does not have it
function Script:describeTargetStep(mechanics, aimPoint, spellTarget) return nil end

return Script
