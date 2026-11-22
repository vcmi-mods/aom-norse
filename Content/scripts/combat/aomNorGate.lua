-- Gate of the Nine Worlds (Norse Grail spell), per-round settlement: after the cast, at the start of each round the next giant lands on our side, until all four (Mountain, Rock, Frost, Fire) have come.
-- This battle event is given by the spell's timed effect to our units present at the cast; the budget (AOM_NOR_GATE) and giants landed so far (AOM_NOR_GATE_N) are written by spells/aomNorGate.lua.
-- Settled once per side per round (like aomReturn.lua): the first unit of a side that finds "own round count > settled round (AOM_NOR_GATE_TICK)" does the landing.
local Base = require("combat/combatScript")
local L = require("lib/aomNorGateLib")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

function Script:onRoundStart(server, battle, unit, other)
	if not unit:isAlive() then return end
	local budget = unit:getBonusesValue({ type = L.BUDGET })
	if budget <= 0 then return end

	local seen = unit:getBonusesValue({ type = L.SEEN }) + 1
	L.setValue(server, battle, unit, L.SEEN, seen)

	local side = unit:getSide()
	local units = battle:getUnitsIf(function(u)
		return u:isAlive() and u:getSide() == side and u:getBonusesValue({ type = L.BUDGET }) > 0
	end)
	local done, count = 0, 0
	for _, u in ipairs(units) do
		done = math.max(done, u:getBonusesValue({ type = L.TICK }))
		count = math.max(count, u:getBonusesValue({ type = L.COUNT }))
	end
	if done >= seen or count >= #L.ORDER then return end

	if L.drop(server, battle, side, budget, count + 1) then count = count + 1 end
	for _, u in ipairs(units) do
		L.setValue(server, battle, u, L.TICK, seen)
		L.setValue(server, battle, u, L.COUNT, count)
	end
end

return Script
