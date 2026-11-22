-- Fenrir's Inferno: our wolves (the Fimbulwinter Wolf line) become fire wolves until the spell ends; after the cast neither side can retreat or surrender.
-- A stack cannot change its look in battle, so the wolves are removed (removeUnit) and the same number of fire wolves not marked as summoned is added in place (addUnit, summoned = false:
-- after battle the engine adds the survivors back to the army by creature; the original wolf slot is cleared as dead). The fire wolves carry combat/aomNorFireWolf (role = wolf, rounds left),
-- and when it expires or the enemy side is wiped out (enemies carry role = watch, checked on any death) they turn back into the same number of wolves, so wolves are what returns to the army.
-- Retreat and surrender: BATTLE_CAN_FLEE and BATTLE_CAN_SURRENDER -100 for the whole battle (heroes are under the battle node and inherit it); the engine only enforces these bans when the other side has a hero.
local Base = require("spells/spellEffect")
local Sac = require("spells/aomNorSacCommon")
local Script = setmetatable({}, {__index = Base})
Script.__index = Script

local MOD = "aom-norse:"
local FIRE = { aomNorWolf = "aomNorWolfFire", aomNorWolfPack = "aomNorWolfPackFire", aomNorWolfFenrir = "aomNorWolfFenrirFire" }

function Script:applicableGeneral(mechanics, problem) return true end
function Script:applicableTarget(mechanics, problem, target) return true end

local function trigger(server, battle, u, role, left, spellKey, level)
	server:addUnitBonus(battle, u, {
		type = "COMBAT_EVENT_TRIGGER", subtype = "aomNorFireWolf", val = left,
		duration = ENUM.BonusDuration.oneBattle, hidden = true,
		sourceType = ENUM.BonusSource.spellEffect, sourceID = spellKey, sourceSecondaryID = level or 0, stacking = "aomNorFireWolf_" .. role,
		addInfo = { role = role }
	}, false)
end

function Script:apply(mechanics, server, target)
	if not server:describeChanges() then return end
	local battle, side = mechanics:getBattle(), mechanics:getCasterSide()
	local spellKey = mechanics:getSpell():getJsonKey()
	local turns = mechanics:getEffectDuration() + (Sac.favoured(self, mechanics) and 1 or 0)
	-- neither side can retreat or surrender (added once)
	local flag = battle:getUnitsIf(function(u) return u:hasBonuses({ type = "AOM_NOR_FIREWOLF_LOCK" }) end)
	if #flag == 0 then
		server:addBattleBonus(battle, { type = "BATTLE_CAN_FLEE", val = -100, duration = ENUM.BonusDuration.oneBattle, sourceType = ENUM.BonusSource.spellEffect, sourceID = spellKey, sourceSecondaryID = mechanics:getEffectLevel(), valueType = ENUM.BonusValueType.additiveValue })
		server:addBattleBonus(battle, { type = "BATTLE_CAN_SURRENDER", val = -100, duration = ENUM.BonusDuration.oneBattle, sourceType = ENUM.BonusSource.spellEffect, sourceID = spellKey, sourceSecondaryID = mechanics:getEffectLevel(), valueType = ENUM.BonusValueType.additiveValue })
		server:addBattleBonus(battle, { type = "AOM_NOR_FIREWOLF_LOCK", val = 1, duration = ENUM.BonusDuration.oneBattle, hidden = true, sourceType = ENUM.BonusSource.spellEffect, sourceID = spellKey, sourceSecondaryID = mechanics:getEffectLevel(), valueType = ENUM.BonusValueType.baseNumber })
		server:appendLog(battle, { append = { "core.bonus.AOM_NOR_FIREWOLF_LOCK.description.1" } })
	end
	-- wolves become fire wolves; existing fire wolves get their timer reset
	local fx = {}
	for _, u in ipairs(battle:getUnitsIf(function(u) return u:isAlive() and u:getSide() == side end)) do
		local key = Sac.shortKey(u)
		if FIRE[key] and not u:isSummoned() and not u:isClone() then
			local count, pos = u:getCount(), u:getPosition()
			server:removeUnit(battle, u)
			local nu = server:addUnit(battle, { count = count, type = LIBRARY:getCreatureByName(MOD .. FIRE[key]), side = side, position = pos, summoned = false })
			if nu == nil then nu = battle:getUnitByPos(pos, true) end
			if nu then trigger(server, battle, nu, "wolf", turns, spellKey, mechanics:getEffectLevel()) fx[#fx + 1] = { unit = nu } end
		elseif key:match("Fire$") and key:match("^aomNorWolf") then
			local old = u:getBonuses({ type = "COMBAT_EVENT_TRIGGER" }):filter(function(b) return b:getStacking() == "aomNorFireWolf_wolf" end)
			if old:size() > 0 then server:removeUnitBonuses(battle, u, old) end
			trigger(server, battle, u, "wolf", turns, spellKey, mechanics:getEffectLevel())
		end
	end
	if #fx > 0 then
		-- all enemies get the "watch", so the fire wolves turn back before the enemy is wiped out
		for _, e in ipairs(battle:getUnitsIf(function(e) return e:isAlive() and e:getSide() ~= side end)) do
			if e:getBonuses({ type = "COMBAT_EVENT_TRIGGER" }):filter(function(b) return b:getStacking() == "aomNorFireWolf_watch" end):size() == 0 then
				trigger(server, battle, e, "watch", 0, spellKey, mechanics:getEffectLevel())
			end
		end
		if self.animation then server:showBattleAnimation(battle, fx, self.animation, "", 1.0, true) end
		server:refreshBattleUnits(battle)
		server:appendLog(battle, { append = { "core.bonus.AOM_NOR_FIREWOLF_LOCK.description.2" }, replaceNumbers = { #fx, turns } })
	end
end

return Script
