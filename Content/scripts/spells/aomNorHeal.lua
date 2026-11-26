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

--- Cursor and status bar text while choosing a target: only the cursor changes (cursor proxy cursor_map.json): Dwarven Armor repairs friendly war machines (healing)
--- The text copies the engine default (BattleSpellMechanics::describeTargetStep): on a unit "Cast X on Y" (core.genrltxt.27, Y singular or plural by count),
--- when it cannot be cast "Select a target for the spell" (23); on a hex "Cast X" (26); damage and healing estimates are appended as usual.
--- Steps (or modes) not listed in the table return nil and fall back to the engine default.
function Script:describeTargetStep(mechanics, partialTarget, hoveredHex)
	local CURSORS = { [1] = "combatHeal" } -- step number -> cursor
	local AIM = { ["*"] = "creature" } -- target type of the first step (spell targetType)
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
