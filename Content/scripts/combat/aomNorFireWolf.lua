-- Fire wolves of Fenrir's Inferno (see spells/aomNorFireWolves.lua):
--   role = wolf (on the fire wolves, val = rounds left): minus one each round start; at 0 they turn back into the same number of wolves
--   role = watch (on enemies): when an enemy dies and the enemy side has no unit left that keeps the battle going, turn all fire wolves of the other side back first (before the engine ends the battle)
local Base = require("combat/combatScript")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local MOD = "aom-norse:"
local BACK = { aomNorWolfFire = "aomNorWolf", aomNorWolfPackFire = "aomNorWolfPack", aomNorWolfFenrirFire = "aomNorWolfFenrir" }

local function shortKey(unit)
	local key = unit:getCreature():getJsonKey()
	return key:match("([^:]+)$") or key
end

local function swapBack(server, battle, u)
	local back = BACK[shortKey(u)]
	if not back or not u:isAlive() then return false end
	local count, pos, side = u:getCount(), u:getPosition(), u:getSide()
	server:removeUnit(battle, u)
	server:addUnit(battle, { count = count, type = LIBRARY:getCreatureByName(MOD .. back), side = side, position = pos, summoned = false })
	return true
end

local function swapSide(server, battle, side)
	local n = 0
	for _, u in ipairs(battle:getUnitsIf(function(u) return u:isAlive() and u:getSide() == side end)) do
		if swapBack(server, battle, u) then n = n + 1 end
	end
	if n > 0 then
		server:refreshBattleUnits(battle)
		server:appendLog(battle, { append = { "core.bonus.AOM_NOR_FIREWOLF_LOCK.description.3" }, replaceNumbers = { n } })
	end
end

--- does this side still have a unit that keeps the battle going (same rule as the engine's battleIsFinished: alive, not an arrow tower or war machine, not a summon or clone)
local function standing(battle, side)
	return #battle:getUnitsIf(function(u)
		return u:isAlive() and u:getSide() == side and not u:isTurret() and not u:hasBonuses({ type = "SIEGE_WEAPON" }) and not u:isSummoned() and not u:isClone()
	end) > 0
end

function Script:onRoundStart(server, battle, unit, other)
	if self.role ~= "wolf" or not unit:isAlive() then return end
	local mine = unit:getBonuses({ type = "COMBAT_EVENT_TRIGGER" }):filter(function(b) return b:getStacking() == "aomNorFireWolf_wolf" end)
	if mine:size() == 0 then return end
	local left = mine:getBonus(1):getVal() - 1
	if left <= 0 then
		swapBack(server, battle, unit)
		server:refreshBattleUnits(battle)
		server:appendLog(battle, { append = { "core.bonus.AOM_NOR_FIREWOLF_LOCK.description.3" }, replaceNumbers = { 1 } })
		return
	end
	server:removeUnitBonuses(battle, unit, mine)
	server:addUnitBonus(battle, unit, { type = "COMBAT_EVENT_TRIGGER", subtype = "aomNorFireWolf", val = left, duration = ENUM.BonusDuration.oneBattle, hidden = true,
		sourceType = ENUM.BonusSource.spellEffect, sourceSecondaryID = 0, stacking = "aomNorFireWolf_wolf", addInfo = { role = "wolf" } }, false)
end

function Script:onDeath(server, battle, unit, other)
	if self.role ~= "watch" then return end
	local side = unit:getSide()
	if standing(battle, side) then return end
	local enemy = side == ENUM.BattleSide.attacker and ENUM.BattleSide.defender or ENUM.BattleSide.attacker
	swapSide(server, battle, enemy)
end

return Script
