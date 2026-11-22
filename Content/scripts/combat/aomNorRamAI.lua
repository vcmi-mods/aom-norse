-- AI handling of the Battering Ram (the AI must ram walls too).
-- While the walls stand the engine's battle AI finds no path to the enemy, so the ram would just wait and defend and never reach the wall; this script makes that move for the AI:
-- in a siege, with the ram on the attacking side and its owner not a human player (AI or neutral), at the start of each round:
--   if it already stands next to a wall part it can ram, it stays (the AI casts Ram Strike itself in its turn: in AI evaluation the spell is valued as damage to enemies, see spells/aomNorRam.lua);
--   otherwise it walks along passable hexes toward the nearest ramming spot, at most as many steps as its speed (it stops in the moat like any normal move).
-- Rams of human players are not affected and use Ram Strike as usual.
local Base = require("combat/combatScript")
local Ram = require("spells/aomNorRam")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local R = setmetatable({ canAttackGate = true, canAttackTowers = true, canAttackKeep = true }, { __index = Ram })
local PARTS = { ENUM.WallPart.gate, ENUM.WallPart.belowGate, ENUM.WallPart.overGate, ENUM.WallPart.bottomWall, ENUM.WallPart.upperWall,
	ENUM.WallPart.bottomTower, ENUM.WallPart.upperTower, ENUM.WallPart.keep }

local function key(h) return h:getX() .. "," .. h:getY() end
local function goodSpot(battle, hex)
	for _, part in ipairs(PARTS) do
		if battle:isWallPartAttackable(part) and R:canHexAttackWallPart(battle, hex, part) then return true end
	end
	return false
end

function Script:onRoundStart(server, battle, unit, other)
	if not unit:isAlive() or not battle:hasFortifications() or unit:getSide() ~= ENUM.BattleSide.attacker then return end
	if GAME and GAME.playerIsHuman and GAME:playerIsHuman(battle:getUnitController(unit)) then return end
	if R:adjacentPart(battle, unit) ~= nil then return end      -- next to the wall: the battle AI casts Ram Strike itself in the ram's turn
	-- breadth-first walk over accessible hexes, up to the unit's speed
	local speed = math.max(1, unit:getBonusesValue({ type = "STACKS_SPEED" }))
	local start = unit:getPosition()
	local seen, frontier, goal = { [key(start)] = true }, { start }, nil
	for _ = 1, speed do
		local nextF = {}
		for _, h in ipairs(frontier) do
			for _, n in ipairs({ h:copyToEast(), h:copyToNorthEast(), h:copyToSouthEast(), h:copyToWest(), h:copyToNorthWest(), h:copyToSouthWest() }) do
				if n:isValid() and n:isAvailable() and not seen[key(n)] then
					seen[key(n)] = true
					if battle:isAccessibleForUnit(unit, n) then
						if goodSpot(battle, n) then goal = n break end
						table.insert(nextF, n)
					end
				end
			end
			if goal then break end
		end
		if goal then break end
		frontier = nextF
	end
	if goal == nil then      -- not reachable this round: step toward the nearest wall-side spot as the crow flies
		local best, bd = nil, 1e9
		for _, h in ipairs(frontier) do
			local d = math.abs(h:getX() - 9) + math.abs(h:getY() - 5) * 0.5
			if d < bd then best, bd = h, d end
		end
		goal = best
	end
	if goal ~= nil and key(goal) ~= key(start) then server:moveUnit(battle, unit, goal, false) end
end

return Script
