-- Undermine: cracks open along the row of the target hex. Enemies on the row take damage ("siegeFactor" times for war machines); in sieges, walls, gate, towers and keep on the row each take "wall" damage.
local Base = require("spells/aomNorDamage")
local Sac = require("spells/aomNorSacCommon")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local function aimHex(target)
	for _, dest in ipairs(target or {}) do
		if dest.hex and dest.hex:isValid() then return dest.hex end
	end
	return nil
end

local function rowOf(target)
	for _, dest in ipairs(target or {}) do
		if dest.hex and dest.hex:isValid() then return dest.hex:getY() end
	end
	return nil
end

function Script:transformTarget(mechanics, aimPoint, spellTarget)
	local y = rowOf(aimPoint)
	if y == nil then return {} end
	local battle, side, seen = mechanics:getBattle(), mechanics:getCasterSide(), {}
	-- the first item carries only the hex, no unit: apply needs to know which row to damage walls on (there may be no enemy on the row)
	local out = { { hex = aimHex(aimPoint) } }
	local arr = battle:getAllPossibleHexes()
	for i = 1, arr:size() do
		local h = arr:at(i)
		if h:getY() == y then
			local u = battle:getUnitByPos(h, true)
			if u and u:getSide() ~= side and not seen[u:unitID()] and not u:isTurret() and self:isValidTarget(mechanics, u) and self:isReceptive(mechanics, u) then
				seen[u:unitID()] = true
				out[#out + 1] = { unit = u, hex = h }
			end
		end
	end
	return out
end

function Script:isValidTarget(mechanics, unit)
	if unit:hasBonuses({ type = "SIEGE_WEAPON" }) then return unit:isAlive() end
	return Base.isValidTarget(self, mechanics, unit)
end

function Script:damageForTarget(targetIndex, mechanics, unit)
	local d = Base.damageForTarget(self, targetIndex, mechanics, unit)
	if unit:hasBonuses({ type = "SIEGE_WEAPON" }) then d = d * (self.siegeFactor or 3) end
	return d
end

function Script:filterTarget(mechanics, target)
	local out = {}
	for _, dest in ipairs(target) do
		if dest.unit == nil or (self:isValidTarget(mechanics, dest.unit) and self:isReceptive(mechanics, dest.unit)) then out[#out + 1] = dest end
	end
	return out
end

function Script:applicableGeneral(mechanics, problem) return true end
function Script:applicableTarget(mechanics, problem, target) return true end

function Script:apply(mechanics, server, target)
	Base.apply(self, mechanics, server, target)
	local battle = mechanics:getBattle()
	if not battle:hasFortifications() or (self.wall or 0) <= 0 then return end
	local y = rowOf(target)
	if y == nil then return end
	local done = {}
	local arr = battle:getAllPossibleHexes()
	for i = 1, arr:size() do
		local h = arr:at(i)
		if h:getY() == y then
			local part = battle:hexToWallPart(h)
			if part ~= ENUM.WallPart.invalid and part ~= ENUM.WallPart.indestructiblePart and part ~= ENUM.WallPart.indestructibleGate and not done[part] then
				done[part] = true
				local st = battle:getWallState(part)
				if st ~= nil and st > 0 then server:catapultAttack(battle, nil, part, self.wall) end
			end
		end
	end
end

-- the engine calls this function when choosing targets; the unitEffect base class does not have it

--- Cursor and status bar text while choosing a target: only the cursor changes (cursor proxy cursor_map.json): Undermine splits the whole row of the target (line type)
--- The text copies the engine default (BattleSpellMechanics::describeTargetStep): on a unit "Cast X on Y" (core.genrltxt.27, Y singular or plural by count),
--- when it cannot be cast "Select a target for the spell" (23); on a hex "Cast X" (26); damage and healing estimates are appended as usual.
--- Steps (or modes) not listed in the table return nil and fall back to the engine default.
function Script:describeTargetStep(mechanics, partialTarget, hoveredHex)
	local CURSORS = { [1] = "kadCursorRay" } -- step number -> cursor
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
