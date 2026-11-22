-- Per-round settlement of Norse god powers placed on the ground (see spells/aomNorSite.lua): each spring / hill fort is settled once, by the stack with the lowest id that carries it.
local Base = require("combat/combatScript")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local function real(server) return not server.describeChanges or server:describeChanges() end

--- steps between two hexes (same algorithm as the engine's BattleHex::getDistance)
local function distance(x1, y1, x2, y2)
	local a1, a2 = x1 + math.floor(y1 / 2), x2 + math.floor(y2 / 2)
	local dx, dy = a2 - a1, y2 - y1
	if (dx >= 0 and dy >= 0) or (dx < 0 and dy < 0) then return math.max(math.abs(dx), math.abs(dy)) end
	return math.abs(dx) + math.abs(dy)
end
local function unitDistance(u, x, y)
	local p = u:getPosition()
	local best = distance(p:getX(), p:getY(), x, y)
	if u:getCreature():isDoubleWide() then      -- other hex of a two-hex unit: the attacker is on the west, the defender on the east
		local q = u:getSide() == ENUM.BattleSide.attacker and p:copyToWest() or p:copyToEast()
		if q:isValid() then best = math.min(best, distance(q:getX(), q:getY(), x, y)) end
	end
	return best
end

local function myTag(unit, x, y, kind)
	local found = nil
	unit:getBonuses({ type = "COMBAT_EVENT_TRIGGER" }):filter(function(b)
		local s = b:getStacking() or ""
		if s:match("@" .. x .. "," .. y .. "$") then found = s end
		return false
	end)
	return found
end

function Script:onRoundStart(server, battle, unit, other)
	if not unit:isAlive() then return end
	local x, y, kind = self.x, self.y, self.kind
	local tag = myTag(unit, x, y, kind)
	if tag == nil then return end
	local side = unit:getSide()
	for _, u in ipairs(battle:getUnitsIf(function(u) return u:isAlive() and u:getSide() == side and u:unitID() < unit:unitID() end)) do
		if myTag(u, x, y, kind) == tag then return end      -- not the leader
	end
	local val = self.val or 0
	if kind == "spring" then
		local fx = {}
		for _, u in ipairs(battle:getUnitsIf(function(u) return u:isAlive() and u:getSide() == side and not u:isTurret() end)) do
			if unitDistance(u, x, y) <= (self.radius or 2) and not u:hasBonuses({ type = "SIEGE_WEAPON" }) and u:getFirstHPleft() < u:getMaxHealth() then
				server:healUnit(battle, u, val, ENUM.HealLevel.heal, ENUM.HealPower.permanent)
				fx[#fx + 1] = { unit = u }
			end
		end
		if real(server) and #fx > 0 then
			if self.animation and self.animation ~= "" then server:showBattleAnimation(battle, fx, self.animation, "", 1.0, true) end
			server:refreshBattleUnits(battle)
			server:appendLog(battle, { append = { "core.bonus.AOM_NOR_SITE.description.1" }, replaceNumbers = { #fx, val } })
		end
	elseif kind == "fort" then
		local best, bd = nil, 99
		for _, u in ipairs(battle:getUnitsIf(function(u) return u:isAlive() and u:getSide() ~= side and not u:isTurret() end)) do
			local d = unitDistance(u, x, y)
			if d < bd or (d == bd and best and u:unitID() < best:unitID()) then best, bd = u, d end
		end
		if best == nil then return end
		local name = best:getCreature():getNameTextID(best:getCount())
		if real(server) and self.animation and self.animation ~= "" then server:showBattleAnimation(battle, { { unit = best } }, self.animation, "", 1.0, true) end
		local hp = math.min(val, best:getAvailableHealth())
		local _, killed = server:damageUnit(battle, best, hp)
		if real(server) then server:appendLog(battle, { append = { "core.bonus.AOM_NOR_SITE.description.2" }, replaceStrings = { name }, replaceNumbers = { hp, killed or 0 } }) end
	end
end

return Script
