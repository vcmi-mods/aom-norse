-- Ram Strike of the Battering Ram (aomNorRamStrike). Taken from the batteringRam mod by Karyoplasma (used with the author's design; Norse IDs so both mods can be installed
-- side by side): the bonus is AOM_NOR_RAM instead of BATTERING_RAM, and the log line is the bonus' own value description.
-- Changed for the AI (so the AI can ram walls too): the spell has no target - the ram hits the wall part it stands next to (gate first, then the
-- walls, the towers, the keep). The battle AI only tries a creature spell's targets on units and random hexes next to them, so a wall hex was almost never
-- tried; and it values a cast by the change in units' health, so in its trial run (describeChanges false) the hit is counted as damage to the strongest enemy.
local Base = require("spells/spellEffect")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local WALLS  = {
	ENUM.WallPart.bottomWall,
	ENUM.WallPart.belowGate,
    ENUM.WallPart.overGate,
	ENUM.WallPart.upperWall
}
local BOTTOM_TOWER = ENUM.WallPart.bottomTower
local UPPER_TOWER = ENUM.WallPart.upperTower
local KEEP = ENUM.WallPart.keep
local GATE = ENUM.WallPart.gate

local ORDER = { GATE, ENUM.WallPart.belowGate, ENUM.WallPart.overGate, ENUM.WallPart.bottomWall, ENUM.WallPart.upperWall, BOTTOM_TOWER, UPPER_TOWER, KEEP }

-- the wall part this ram can hit from where it stands (nil: none)
function Script:adjacentPart(battle, caster)
	for _, part in ipairs(ORDER) do
		if battle:isWallPartAttackable(part) and self:canCasterAttackWallPart(battle, caster, part) then return part end
	end
	return nil
end

function Script:hasNoPotentialTargets(battle)
	for _, p in ipairs(WALLS) do
		if battle:isWallPartAttackable(p) then
			return false
		end
	end
	if self.canAttackGate and battle:isWallPartAttackable(GATE) then
		return false
	end
	if self.canAttackTowers then
		if battle:isWallPartAttackable(UPPER_TOWER) or battle:isWallPartAttackable(BOTTOM_TOWER) then
			return false
		end
	end
	if self.canAttackKeep and battle:isWallPartAttackable(KEEP) then
		return false
	end
	return true
end

function Script:randomDamage(server, sumOfVal)
	local val = math.max(0, sumOfVal)
    local baseDmg = math.floor(val / 100)
    local extraChance = val % 100
    local r = server:rngInt(0, 99)

    if r < extraChance then
        return baseDmg + 1
    end

    return baseDmg
end

function Script:allowedToAttackWallPart(wallPart)
    for _, p in ipairs(WALLS) do
        if wallPart == p then
            return true
        end
    end

    if self.canAttackGate and wallPart == GATE then
        return true
    end

	if self.canAttackTowers then
		if wallPart == BOTTOM_TOWER or wallPart == UPPER_TOWER then
			return true
		end
	end

    return self.canAttackKeep and wallPart == KEEP
end

function Script:canCasterAttackWallPart(battle, attacker, wallPart)
	return self:canHexAttackWallPart(battle, attacker:getPosition(), wallPart)
end

-- a ram standing at casterHex can hit wallPart (also used by combat/aomNorRamAI.lua for places the ram could walk to)
function Script:canHexAttackWallPart(battle, casterHex, wallPart)
	if not self:allowedToAttackWallPart(wallPart) then return false end
	local hex = battle:wallPartToBattleHex(wallPart)

	if wallPart == GATE then
		return casterHex == hex:copyToWest():copyToWest()
	end

	if wallPart == BOTTOM_TOWER then
		hex = hex:copyToWest()
	end

	if wallPart == KEEP then
		hex = hex:copyToSouthWest():copyToSouthWest():copyToSouthWest():copyToSouthEast():copyToSouthEast()
	end

	local hexes = {
		hex:copyToWest(),
		hex:copyToNorthWest(),
		hex:copyToSouthWest()
	}
	for _, targetHex in ipairs(hexes) do
		if casterHex == targetHex then
			return true
		end
	end

	return false
end

function Script:applicableTarget(mechanics, problem, target)
	if target == nil or #target == 0 or target[1].hex == nil or not target[1].hex:isValid() then return true end      -- no target: the ram hits the wall part next to it
	local battle = mechanics:getBattle()
	local hex = target[1].hex
	local wallPart = battle:hexToWallPart(hex)
	local caster = mechanics:getUnitCaster()

	if 	not caster
		or wallPart < 0
		or not battle:isWallPartAttackable(wallPart)
		or not self:canCasterAttackWallPart(battle, caster, wallPart)
	then
		problem:addStandard(mechanics, ENUM.SpellCastProblem.wrongSpellTarget)
		return false
	end

	return true
end

function Script:applicableGeneral(mechanics, problem)
	local battle = mechanics:getBattle()

	if not battle:hasFortifications()
	   or mechanics:getCasterSide() ~= ENUM.BattleSide.attacker
	   or self:hasNoPotentialTargets(battle)
	   or not mechanics:getUnitCaster()
	   or self:adjacentPart(battle, mechanics:getUnitCaster()) == nil
	then
		problem:addStandard(mechanics, ENUM.SpellCastProblem.noAppropriateTarget)
		return false
	end

	return true
end

function Script:apply(mechanics, server, target)
	local battle = mechanics:getBattle()
	local attacker  = mechanics:getUnitCaster()
	local part = self:adjacentPart(battle, attacker)
	if part == nil then return end
	if not server:describeChanges() then
		local best, bv = nil, -1
		for _, u in ipairs(battle:getUnitsIf(function(u) return u:isAlive() and u:getSide() ~= attacker:getSide() and not u:isTurret() end)) do
			local v = u:getAvailableHealth()
			if v > bv then best, bv = u, v end
		end
		if best then server:damageUnit(battle, best, math.min(bv, math.max(1, attacker:getCount()) * 30)) end
		return
	end
	local attackStrength = attacker:getBonusesValue({ type = "AOM_NOR_RAM" })
	local damage = self:randomDamage(server, attackStrength)
	server:catapultAttack(battle, nil, part, damage)
	self:describe(server, battle, attacker, damage)
end

function Script:describe(server, battle, attacker, damage)
	local count = attacker:getCount()
	server:appendLog(battle, {
		append         = { "core.bonus.AOM_NOR_RAM.description.1" },
		replaceStrings = { attacker:getCreature():getNameTextID(count) },
		replaceNumbers = { damage }
	})
end

return Script