-- Gate of the Nine Worlds (Norse Grail spell, all four giants within four rounds), shared code: one giant lands each time in the order Mountain, Rock, Frost, Fire, until all four have come.
-- On casting (spells/aomNorGate.lua) the first lands at once, and our units record the health budget per stack (AOM_NOR_GATE) and the number landed (AOM_NOR_GATE_N);
-- after that one more lands at each round start (combat/aomNorGate.lua), stopping after the fourth.
local M = {}

M.BUDGET, M.COUNT, M.SEEN, M.TICK = "AOM_NOR_GATE", "AOM_NOR_GATE_N", "AOM_NOR_GATE_SEEN", "AOM_NOR_GATE_TICK"
M.FX = "aom/nor/fx/fxRuneCircle.json"
M.SCREEN_FX = "aom/nor/fx/fxGateScreen.json"      -- full-battlefield animation on casting (as Return to Atlantis)
M.ORDER = { "aom-norse:aomNorMountainGiant", "aom-norse:aomNorRockGiant", "aom-norse:aomNorFrostGiant", "aom-norse:aomNorFireGiant" }

local function real(server)
	return not server.describeChanges or server:describeChanges()
end

--- hex for the full-battlefield animation: 8th hex of the bottom row (y = 10) (image 820x1012, battlefield at the top left)
function M.screenHex(battle)
	local arr = battle:getAllPossibleHexes()
	for i = 1, arr:size() do
		local h = arr:at(i)
		if h:getY() == 10 and h:getX() == 8 then return h end
	end
	return nil
end

--- write one numeric marker on a unit (removing the old one first)
function M.setValue(server, battle, unit, bonusType, value)
	local old = unit:getBonuses({ type = bonusType })
	if old:size() > 0 then server:removeUnitBonuses(battle, unit, old) end
	if value > 0 then
		server:addUnitBonus(battle, unit, {
			type = bonusType, sourceType = ENUM.BonusSource.other, val = value,
			valueType = ENUM.BonusValueType.baseNumber, duration = ENUM.BonusDuration.oneBattle, hidden = true
		}, false)
	end
end

--- land giant number index: total health budget, at least 1. If there is no free hex nothing lands this round (the same giant is tried next round).
function M.drop(server, battle, side, budget, index)
	if budget <= 0 or index < 1 or index > #M.ORDER then return false end
	local creature = LIBRARY:getCreatureByName(M.ORDER[index])
	if creature == nil then return false end
	local count = math.max(1, math.floor(budget / creature:getMaxHealth()))
	local hex = battle:getAvailableHex(creature, side)
	if not hex:isValid() then return false end
	server:addUnit(battle, { count = count, type = creature, side = side, position = hex, summoned = true })
	if real(server) then
		server:appendLog(battle, {
			append = { "core.bonus." .. M.BUDGET .. ".description.1" },
			replaceStrings = { creature:getNameTextID(count) }, replaceNumbers = { count }
		})
	end
	return true
end

return M
