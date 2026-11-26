-- Gate of the Nine Worlds (Norse Grail spell), cast effect: the Mountain Giant lands at once, then the Rock, Frost and Fire Giants land at the start of each following round until all four have come.
-- Health budget per stack = power x this level's power (same formula as core summon spells), stored on our units (AOM_NOR_GATE). Castable once per battle.
local Base = require("spells/summon")
local L = require("lib/aomNorGateLib")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local function own(battle, side)
	return battle:getUnitsIf(function(u) return u:isAlive() and not u:isGhost() and u:getSide() == side end)
end

-- once per battle: cannot be cast again if any of our units (dead ones included) carries the marker. Checking only living units let the AI cast it again after the first stacks were wiped out
function Script:applicableGeneral(mechanics, problem)
	local side = mechanics:getCasterSide()
	for _, u in ipairs(mechanics:getBattle():getUnitsIf(function(u) return u:getSide() == side end)) do
		if u:getBonusesValue({ type = L.SEEN }) > 0 then
			problem:addGeneric(mechanics)
			return false
		end
	end
	return true
end

function Script:applicableTarget(mechanics, problem, target) return true end

function Script:transformTarget(mechanics, aimPoint, spellTarget)
	if #aimPoint > 0 then return { aimPoint[1] } end
	return spellTarget
end

function Script:apply(mechanics, server, target)
	local battle, side = mechanics:getBattle(), mechanics:getCasterSide()
	local budget = math.floor(self:summonedEffectValue(mechanics))
	if budget <= 0 then return end
	local trial = server.describeChanges and not server:describeChanges()
	if not trial then      -- full-battlefield animation: the Gate of the Nine Worlds opens; the first giant lands after it has played (not deferred)
		local hex = L.screenHex(battle)
		if hex ~= nil then server:showBattleAnimation(battle, { { hex = hex } }, L.SCREEN_FX, "", 1.0, false) end
	end
	-- AI evaluation only sees this one cast: report it as 4 stacks (three more come in the next rounds); evaluation changes never reach the real battlefield
	local n = L.drop(server, battle, side, trial and budget * 4 or budget, 1) and 1 or 0
	for _, u in ipairs(own(battle, side)) do
		L.setValue(server, battle, u, L.BUDGET, budget)
		L.setValue(server, battle, u, L.COUNT, n)
		L.setValue(server, battle, u, L.SEEN, 1)
	end
end

--- Cursor and status bar text while choosing a target: return nil to use the engine default ("Cast X on Y" / "Cast X", with damage and healing estimates added automatically).
--- Every spell effect script must define this function.
function Script:describeTargetStep(mechanics, partialTarget, hoveredHex)
	return nil
end

--- Hover estimate: the first giant that drops when cast (L.ORDER[1]), count computed the same way as apply / L.drop:
--- max(1, health budget / health of one), health budget = summonedEffectValue. Giants arriving in later rounds are not counted
function Script:getHealthChange(mechanics, spellTarget)
	local zero = { hpDelta = 0, unitsDelta = 0 }
	local ok, result = pcall(function()
		local budget = math.floor(self:summonedEffectValue(mechanics))
		if budget <= 0 then return zero end
		local creature = LIBRARY:getCreatureByName(L.ORDER[1])
		if creature == nil then return zero end
		if not mechanics:getBattle():getAvailableHex(creature, mechanics:getCasterSide()):isValid() then return zero end
		local count = math.max(1, math.floor(budget / creature:getMaxHealth()))
		return { hpDelta = count * creature:getMaxHealth(), unitsDelta = count, unitType = creature }
	end)
	if ok and result then return result end
	return zero
end

return Script
