-- Dash of Fenrir's Inferno: Fenrir charges from the caster's side along the row of the target hex up to that hex, biting enemies on the way (damage as core damage, including the Soul Offering bonus).
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

--- Cursor and status bar text while choosing a target: only the cursor changes (cursor proxy cursor_map.json): Fenrir's Inferno, Fenrir dashes along the target row (the dash key comes before explode in the spell, so it decides the cursor)
--- The text copies the engine default (BattleSpellMechanics::describeTargetStep): on a unit "Cast X on Y" (core.genrltxt.27, Y singular or plural by count),
--- when it cannot be cast "Select a target for the spell" (23); on a hex "Cast X" (26); damage and healing estimates are appended as usual.
--- Steps (or modes) not listed in the table return nil and fall back to the engine default.
function Script:describeTargetStep(mechanics, partialTarget, hoveredHex)
	local CURSORS = { [1] = "kadCursorCharge" } -- step number -> cursor
	local AIM = { ["*"] = "location" } -- target type of the first step (spell targetType)
	if hoveredHex == nil or not hoveredHex:isValid() or mechanics:isMassive() then return nil end
	local step = #partialTarget + 1
	local cursor = CURSORS[step]
	if cursor == nil then return nil end
	local spell = mechanics:getSpell()
	if step ~= 1 then return nil end
	local aim = AIM[spell:getJsonKey()] or AIM["*"]
	if aim ~= "creature" and aim ~= "location" then return nil end
	local spellName = spell:getNameTextID()
	if aim == "creature" then
		local battle = mechanics:getBattle()
		local unit = battle:getUnitByPos(hoveredHex, true) or battle:getUnitByPos(hoveredHex, false)
		local names = { spellName }
		if unit ~= nil then table.insert(names, unit:getCreature():getNameTextID(unit:getCount())) end
		return {
			cursor = cursor,
			text = { append = { "core.genrltxt.27" }, replaceStrings = names }, -- Cast %s on %s
			blockedText = { append = { "core.genrltxt.23" } },                  -- Select a target for the spell
			healthGainTextID = "vcmi.battleWindow.healValuePreview"
		}
	end
	return {
		cursor = cursor,
		text = { append = { "core.genrltxt.26" }, replaceStrings = { spellName } }, -- Cast %s
		healthGainTextID = "vcmi.battleWindow.healValuePreview"
	}
end

return Script
